# Plan Evaluation

> [!NOTE]
> Korean version: [ai-model-plan-eval.README.kr.md](../../../docs/localization/ai-model-plan-eval.README.kr.md)

This directory contains scripts and datasets for comparing plan-stage language models.

## Measurements

- Output format and JSON parsing
- Equipment and material precision and recall
- Hallucination checks
- Summary quality
- Generation speed and token throughput

## Run

```powershell
python -m scripts.plan_eval.run_speed
python -m scripts.plan_eval.run_quality
python -m scripts.plan_eval.compare
```

Evaluation output and generated reports should be kept outside source-control-sensitive directories unless intentionally shared.

## Korean Documentation

- [Korean Plan Evaluation README](../../../docs/localization/ai-model-plan-eval.README.kr.md)
