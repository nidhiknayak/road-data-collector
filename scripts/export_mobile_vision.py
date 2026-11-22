#!/usr/bin/env python3
"""Export the frozen road model for Android. No retraining or label changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path

os.environ.setdefault('ORT_DISABLE_TELEMETRY','1')

import joblib
import numpy as np
import onnx
import onnxruntime as ort
import torch
import torch.nn.functional as functional
from transformers import AutoModel, SegformerForSemanticSegmentation


class RoadProbability(torch.nn.Module):
    def __init__(self, model):
        super().__init__();self.model=model

    def forward(self, pixels):
        probability=self.model(pixel_values=pixels).logits.softmax(1)[:,0:1]
        return functional.interpolate(probability,size=pixels.shape[-2:],mode='bilinear',align_corners=False)


class SurfaceEmbedding(torch.nn.Module):
    def __init__(self,model):
        super().__init__();self.model=model

    def forward(self,pixels):
        hidden=self.model(pixel_values=pixels).last_hidden_state
        return torch.cat([hidden[:,0],hidden[:,1:].mean(1)],1).mean(0)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-file',default='/home/vlns/road_model_evaluation/selected/road_classifier_v3.joblib')
    parser.add_argument('--output',default=str(Path(__file__).resolve().parents[1]/'android/app/src/main/assets/road_models'))
    args=parser.parse_args();torch.set_num_threads(4)
    output=Path(args.output);output.mkdir(parents=True,exist_ok=True)
    bundle=joblib.load(args.model_file);pipeline=bundle['model']
    assert bundle['feature_mode']=='surface'
    assert pipeline.named_steps['scale'].__class__.__name__=='Normalizer'
    head=pipeline.named_steps['classifier']
    assert head.coef_.shape==(4,1536), 'This exporter supports the selected surface logistic model'
    assert pipeline.named_steps['select'].transformers_[0][2]==list(range(1536))
    segmenter=SegformerForSemanticSegmentation.from_pretrained(bundle['segmenter_id'],local_files_only=True,attn_implementation='eager').eval()
    encoder=AutoModel.from_pretrained(bundle['encoder_id'],local_files_only=True,attn_implementation='eager').eval()
    torch.manual_seed(7)
    exports=[('road_mask.onnx',RoadProbability(segmenter).eval(),torch.randn(1,3,512,288),
              {'pixels':{2:'height',3:'width'},'output':{2:'height',3:'width'}}),
             ('road_embedding.onnx',SurfaceEmbedding(encoder).eval(),torch.randn(2,3,224,224),None)]
    checks={}
    for name,model,pixels,axes in exports:
        dest=output/name
        torch.onnx.export(model,pixels,str(dest),input_names=['pixels'],output_names=['output'],
                          dynamic_axes=axes,opset_version=17,dynamo=False)
        onnx.checker.check_model(str(dest))
        options=ort.SessionOptions();options.intra_op_num_threads=4
        session=ort.InferenceSession(str(dest),sess_options=options,providers=['CPUExecutionProvider'])
        with torch.inference_mode():expected=model(pixels).numpy()
        actual=session.run(None,{'pixels':pixels.numpy()})[0]
        error=float(np.max(np.abs(expected-actual)))
        assert error<.001,(name,error)
        if axes:
            alternate=torch.randn(1,3,288,512)
            with torch.inference_mode():reference=model(alternate).numpy()
            other=session.run(None,{'pixels':alternate.numpy()})[0]
            assert np.max(np.abs(reference-other))<.001
        checks[name]={'max_abs_error':error,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'bytes':dest.stat().st_size}
        print(name,checks[name],flush=True)
    evaluation_file=Path(args.model_file).parent/'final_test_report.json'
    evaluation=json.loads(evaluation_file.read_text())['models']['v3'] if evaluation_file.exists() else {}
    metadata={
        'model_id':'road-surface-v3-20261122','preprocessing_version':bundle['preprocessing_version'],
        'labels':head.classes_.tolist(),'coefficients':head.coef_.tolist(),'intercepts':head.intercept_.tolist(),
        'embedding_size':768,'window_frames':5,'minimum_frames':3,'minimum_score':.5,
        'road_probability_threshold':.55,'minimum_road_fraction':.02,
        'camera_cutoffs':{'car_front':.68,'car_side':.88,'bike':.85,'handheld':1.0},
        'test_video_accuracy':evaluation.get('video_accuracy',-1),
        'test_videos':evaluation.get('videos',0),'experimental':True,
        'source_model_sha256':hashlib.sha256(Path(args.model_file).read_bytes()).hexdigest(),
        'export_checks':checks,
    }
    # Check the portable L2 + linear + softmax head against scikit-learn.
    vectors=np.random.default_rng(5).normal(size=(12,1544)).astype(np.float32)
    meanstd=vectors[:,:1536].astype(np.float64);meanstd/=np.linalg.norm(meanstd,axis=1,keepdims=True)
    logits=meanstd@head.coef_.T+head.intercept_;logits-=logits.max(1,keepdims=True)
    probability=np.exp(logits);probability/=probability.sum(1,keepdims=True)
    error=float(np.max(np.abs(probability-pipeline.predict_proba(vectors))))
    assert error<1e-6,error
    metadata['head_max_abs_error']=error
    (output/'classifier.json').write_text(json.dumps(metadata,separators=(',',':')))
    print('Export verified and saved:',output,flush=True)


if __name__=='__main__':main()
