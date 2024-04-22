# %%
import os
from pathlib import Path

import yaml
import pandas
import geopandas
from typing import Optional, Literal

import bridge_report.bridge_report as bridge_report
import output_summary.output_summary as output_summary
import _Map_Automation.build_map_files as build_map_files


cd = Path(os.getcwd())


def query_yes_no(
    question,
    default=None,
    # question: str, default: Optional[Literal["yes", "no"] | bool] = None
) -> bool:
    """Ask a yes/no question via raw_input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
            It must be "yes" (the default), "no" or None (meaning
            an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    if isinstance(default, bool):
        bool_to_str = {True: "yes", False: "no"}
        default = bool_to_str[default]

    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        print(question + prompt)
        choice = input().lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            print("Please respond with 'yes' or 'no' " "(or 'y' or 'n').\n")


def query_filepath_input(
    question,
    default_path=None,
    incorrect_path_message="The path does not exist, provide path to existing folder",
) -> Path:
    assert question[-2:] == ": "
    if default_path is not None:
        question = question[:-2] + f"(leave blank for {default_path}): "

    valid_path_given = False
    while not valid_path_given:
        hopefully_valid_filepath = input(question)
        if default_path is not None and hopefully_valid_filepath == "":
            return default_path

        try:
            path = Path(hopefully_valid_filepath)
        except Exception:
            print(
                "The path is not recognized as a valid path, please limit you path to letters, numbers and \\"
            )
            continue

        if path.exists():
            # we know our path exists so we are safe
            return path
        else:
            print(incorrect_path_message)

    raise Exception(
        "Somehow valid Path given got set to true, please find valid_path_given = True in this function and delete it or you broke out of the while loop"
    )


def get_config():
    config_filepaths = [
        "MODEL_RESULTS",
        "MAP_OUTPUT",
        "SUMMARY_OUTPUT",
        "BRIDGE_REPORT_LOCATION",
    ]
    config_bools = [
        "CREATE_MAP_OUTPUT",
        "CREATE_CSV_OUTPUT",
        "CREATE_BRIDGE_REPORT",
    ]

    config_path = cd / "config.yml"
    if config_path.exists():
        with open(cd / "config.yml") as f:
            config = yaml.safe_load(f)
            f.close()
        manually_modify_inputs = query_yes_no(
            "Config file was found, would you like to use the config for all inputs: "
        )
        if manually_modify_inputs:
            for key in config.keys():
                if key in config_filepaths:
                    config[key] = Path(config[key])

            return config
    else:
        # we dont have any default values to fall back on
        print("Config file not found, creating manually...")
        config = dict()

    modified_config = {}

    for conf_param_name in config_bools:
        display_name = conf_param_name.lower().replace("_", " ")
        modified_config[conf_param_name] = query_yes_no(
            question=f"{display_name}: ",
            default=config.get(conf_param_name),
        )

    for conf_param_name in config_filepaths:
        display_name = conf_param_name.lower().replace("_", " ")
        modified_config[conf_param_name] = query_filepath_input(
            question=f"Please input the filepath for {display_name}: ",
            default_path=config.get(conf_param_name),
        )

    if query_yes_no(
        "Would you like to replace the old config with these new values?", default="no"
    ):
        save_config = modified_config.copy()
        for key in config_filepaths:
            save_config[key] = str(config[key])

        with open(cd / "config.yml", "w") as file:
            yaml.dump(save_config, file)

    for key in config_filepaths:
        modified_config[key] = Path(modified_config[key])
    return modified_config


# %%
if __name__ == "__main__":
    config = get_config()

    if config["CREATE_MAP_OUTPUT"]:
        ...
        print("Creating map outputs...")
        # build_map_files.build_map_files(config["MODEL_RESULTS"], config["MAP_OUTPUT"])

    if config["CREATE_CSV_OUTPUT"]:
        print("Creating CSVs this will take 5-10 min...")
        output_summary.summaries_model_outputs(
            config["MODEL_RESULTS"], config["SUMMARY_OUTPUT"]
        )

    if config["CREATE_BRIDGE_REPORT"]:
        print(
            f"Creating Bridge Report, please make sure {config['SUMMARY_OUTPUT']} contains a valid set of output CSVs..."
        )
        bridge_report.create_bridge_report(
            config["SUMMARY_OUTPUT"],
            config["BRIDGE_REPORT_LOCATION"] / "bridge_report.xlsx",
        )

    print("done")
