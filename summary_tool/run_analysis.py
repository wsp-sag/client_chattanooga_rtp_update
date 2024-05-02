# %%
import os
from pathlib import Path

import yaml
import pandas
import geopandas
from typing import Optional, Literal

import scripts._Bridge_Report.bridge_report as bridge_report
import scripts._Project_Evaluation.project_evaluation as project_evaluation


cd = Path(os.getcwd())

MODEL_OUTPUT_PATH = cd / "model_output"
SUMMARY_OUTPUT_PATH = cd / "summary_output"
LINK_QUERY_LOOKUP = cd / "lookups"


def get_config():

    config_path = cd / "config.yml"
    if config_path.exists():
        with open(config_path,'r') as f:
            config = yaml.safe_load(f)
            f.close()
    else:
        raise FileNotFoundError("Error: config.yml not found")

    return config





# print(config)

#%%

if __name__ == "__main__":
    config = get_config()

    
    if config["bridge_report"]['CREATE_BRIDGE_REPORT']:
        print("creating bridge report subsets...")
        for subset_name, links in config["bridge_report"]["subset_stats"].items():
            # bridge_report.subset_catagories(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, "2019", subset_name, links)
            bridge_report.subset_catagories(MODEL_OUTPUT_PATH, SUMMARY_OUTPUT_PATH, "2019", subset_name, links)
        print("creating bridge report")
        bridge_report.create_bridge_report(
            MODEL_OUTPUT_PATH, 
            SUMMARY_OUTPUT_PATH, 
            config["bridge_report"]['scenario'],
            config["bridge_report"]['county'],
        )
        print("finish bridge report")

    if config["project_evaluation"]['CREATE_EVALUATION_REPORT']:
        print("creating project evaluation report")
        project_evaluation.create_project_evaluation(
            MODEL_OUTPUT_PATH, 
            SUMMARY_OUTPUT_PATH, 
            config["bridge_report"]['scenario'],
            LINK_QUERY_LOOKUP / config["project_evaluation"]["link_query"],
        )
        print("finish project evaluation report")


    print("done")

#%%