# %%
import os
from pathlib import Path

import yaml
import pandas
import geopandas
from typing import Optional, Literal

import scripts._Bridge_Report.bridge_report as bridge_report
import scripts._Project_Evaluation.project_evaluation as project_evaluation
import scripts._Scenario_Impact.scenario_impact as scenario_impact


cd = Path(os.getcwd())

MODEL_OUTPUT_PATH = cd / "model_output"
SUMMARY_OUTPUT_PATH = cd / "summary_output"
LINK_QUERY_LOOKUP = cd / "lookups"


def get_config():
    config_path = cd / "config.yml"
    if config_path.exists():
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)
            f.close()
    else:
        raise FileNotFoundError("Error: config.yml not found")

    return config


# %%
from importlib import reload

reload(scenario_impact)
if __name__ == "__main__":
    config = get_config()

    if config["scenario_impact"]["CREATE_IMPACT_REPORT"]:
        print("creating impact report subsets...")
        scenario_impact.subset_catagories(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            scenario_impact._get_link_lookups(LINK_QUERY_LOOKUP),
            config["scenario_impact"]["scenario"],
        )
        scenario_impact.consolidate_one_report(SUMMARY_OUTPUT_PATH)

    if config["bridge_report"]["CREATE_BRIDGE_REPORT"]:
        print("creating bridge report")
        bridge_report.create_bridge_report(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            config["bridge_report"]["scenario"],
            config["bridge_report"]["county"],
        )
        print("finish bridge report")

    if config["project_evaluation"]["CREATE_EVALUATION_REPORT"]:
        print("creating project evaluation report")
        project_evaluation.create_project_evaluation(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            config["bridge_report"]["scenario"],
            LINK_QUERY_LOOKUP / config["project_evaluation"]["link_query"],
        )
        print("finish project evaluation report")

    print("done")

# %%
