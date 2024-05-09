#%%
import os
from pathlib import Path
from datetime import datetime

import yaml
import pandas
import geopandas
import subprocess

import _Bridge_Report.bridge_report as bridge_report
import _Project_Evaluation.project_evaluation as project_evaluation
import _Scenario_Impact.scenario_impact as scenario_impact
import _Map_Automation.build_map_files as build_map_files


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

if True:
    config = get_config()

    if config["scenario_impact"]["CREATE_IMPACT_REPORT"]:
        print(f"{datetime.now()} creating impact report subsets...")
        scenario_impact.subset_catagories(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            pandas.read_csv(
                LINK_QUERY_LOOKUP / config["scenario_impact"]["link_query"]
            ),
            config,
        )
        scenario_impact.consolidate_one_report(SUMMARY_OUTPUT_PATH)
        print(f"{datetime.now()} finish impact report")
        

    if config["bridge_report"]["CREATE_BRIDGE_REPORT"]:
        print(f"{datetime.now()} creating bridge report")
        bridge_report.create_bridge_report(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            config["bridge_report"]["scenario"],
            config["bridge_report"]["county"],
        )
        print(f"{datetime.now()} finish bridge report")

    if config["project_evaluation"]["CREATE_EVALUATION_REPORT"]:
        print(f"{datetime.now()} creating project evaluation report")
        project_evaluation.create_project_evaluation(
            MODEL_OUTPUT_PATH,
            SUMMARY_OUTPUT_PATH,
            config["bridge_report"]["scenario"],
            LINK_QUERY_LOOKUP / config["project_evaluation"]["link_query"],
        )
        print(f"{datetime.now()} finish project evaluation report")

    
    if config["map_automation"]["CREATE_MAP_OUTPUT"]:
        print(f"{datetime.now()} postprocessing model outputs for map automation")
        SHP_SAVE_PATH = MAP_DATA_PATH / "Model_Output"

        for scenario in config["map_automation"]["scenario"]:
            build_map_files.model_output_postprocess(
                MODEL_OUTPUT_PATH,
                MAP_DATA_PATH,
                SHP_SAVE_PATH,
                str(scenario),
                LINK_QUERY_LOOKUP
            )
            
            print(f"{datetime.now()} creating pdf maps")
            generate_map_script =  cd / "scripts" / "_Map_Automation" / "Maps_Automate.py"
            qgis_python_path = config['map_automation']['qgis_python_path']
            python_executable_path = config['map_automation']['python_executable_path']
            
            os.environ["PYTHONPATH"] = qgis_python_path
            subprocess.run([str(python_executable_path), str(generate_map_script)] + [str(scenario)], shell=True)
        print(f"{datetime.now()} finish pdf maps")
   

    print("done")


# %%
