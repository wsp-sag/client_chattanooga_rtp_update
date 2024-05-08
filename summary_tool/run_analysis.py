# %%
import os
from pathlib import Path

import yaml
import pandas
import geopandas
import subprocess

from typing import Optional, Literal

import scripts._Bridge_Report.bridge_report as bridge_report
import scripts._Project_Evaluation.project_evaluation as project_evaluation
import scripts._Scenario_Impact.scenario_impact as scenario_impact
import scripts._Map_Automation.build_map_files as build_map_files


cd = Path(os.getcwd())

MODEL_OUTPUT_PATH = cd / "model_output"
SUMMARY_OUTPUT_PATH = cd / "summary_output"
LINK_QUERY_LOOKUP = cd / "lookups"
MAP_DATA_PATH = cd / "scripts" / "_Map_Automation" / "Data"


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
import warnings
warnings.filterwarnings("ignore")

if __name__ == "__main__":
    config = get_config()

    if config["scenario_impact"]["CREATE_IMPACT_REPORT"]:
        print("creating impact report subsets...")
        scenario_impact.subset_catagories(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            pandas.read_csv(
                LINK_QUERY_LOOKUP / config["scenario_impact"]["link_query"]
            ),
            config,
        )
        scenario_impact.consolidate_one_report(SUMMARY_OUTPUT_PATH)
        print("done")
        

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

    
    if config["map_automation"]["OUTPUT_POSTPROCESS"]:
        print("postprocessing model outputs")
        SHP_SAVE_PATH = MAP_DATA_PATH / "Model_Output"
        build_map_files.model_output_postprocess(
            MODEL_OUTPUT_PATH,
            MAP_DATA_PATH,
            SHP_SAVE_PATH,
            config["map_automation"]["scenario"],
            LINK_QUERY_LOOKUP
        )
        print("finish model outputs postprocess")

        if config["map_automation"]["CREATE_MAP_OUTPUT"]:
            print("generating pdf maps")
            generate_map_script =  cd / "scripts" / "_Map_Automation" / "Maps_Automate.py"
            qgis_python_path = config['map_automation']['qgis_python_path']
            python_executable_path = config['map_automation']['python_executable_path']
            
            os.environ["PYTHONPATH"] = qgis_python_path
            subprocess.run([python_executable_path, generate_map_script], shell=True)
            print("finish pdf maps")
   

    print("done")


# %%
