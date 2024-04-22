# %%
import pandas as pd
from pathlib import Path

# cd = Path(os.getcwd())
# with open(cd.parent.parent / "config.yml") as f:
#     config = yaml.safe_load(f)
# SUMMARY_OUTPUT_PATH = Path(config["SUMMARY_OUTPUT"])
# BRIDGE_REPORT_PATH = Path(config["BRIDGE_REPORT_LOCATION"])
# BRIDGE_REPORT_PATH = BRIDGE_REPORT_PATH / "bridge_report.xlsx"

# %%


def create_bridge_report(summary_output_path, bridge_report_path):
    all_summaries: dict[str, pd.DataFrame] = dict()
    for csv in summary_output_path.glob("*.csv"):
        all_summaries[csv.stem] = pd.read_csv(csv)

    first_sheets = [
        "key_stats",
        "network_summary",
        "total_trip_tables",
        "total_Truck_OD",
    ]
    order_of_sheets = first_sheets + [
        key for key in all_summaries.keys() if key not in first_sheets
    ]
    ordered_sums = dict()
    for file_name in order_of_sheets:
        # POP to save memory - not strictly necessary
        ordered_sums[file_name] = all_summaries.pop(file_name)

    with pd.ExcelWriter(bridge_report_path, engine="openpyxl") as writer:
        for sheet_name, df in ordered_sums.items():
            print(sheet_name)
            df.to_excel(writer, sheet_name=sheet_name)


if __name__ == "__main__":
    create_bridge_report(SUMMARY_OUTPUT_PATH, BRIDGE_REPORT_PATH)

# %%
