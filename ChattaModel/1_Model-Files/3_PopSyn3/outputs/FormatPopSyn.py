# Originally created by nagendra.dhakar on 05/29/2014
# Update by WSP on 10/6/2026 due to PopSynIII to JavaPop conversion

# %%
import os
import pandas as pd

output_dir = r"C:\ChattaModel\1_Model-Files\3_PopSyn3\outputs"
intermediate_dir = r"C:\ChattaModel\1_Model-Files\3_PopSyn3\intermediate"

personFileName = "synpop_person.csv"
householdFileName = "synpop_hh.csv"

household_out = "chattanooga_household.dat"
person_out = "chattanooga_person.dat"


def read_population(filename):
    frame = pd.read_csv(os.path.join(output_dir, filename))
    frame.columns = frame.columns.str.strip().str.lower()
    if "hhid" not in frame.columns and "tempid" in frame.columns:
        frame = frame.rename(columns={"tempid": "hhid"})
    return frame


def get_worker_type(employed, work_hours):
    if employed == 0 or work_hours <= 0:
        return 0
    elif work_hours >= 32 and work_hours <= 150:
        return 1
    else:
        return 2


def get_student_type(school_grade, age):
    if school_grade > 0 or (age >= 5 and age < 18):
        return 1
    else:
        return 0


def get_person_type(age, worker_type, work_hours, student_type, school_grade):
    if age < 5:
        return 8
    elif age < 16:
        return 7
    elif worker_type > 0 and work_hours >= 32 and work_hours <= 150:
        return 1
    elif student_type > 0 and age >= 16 and age < 18:
        return 6
    elif school_grade > 0 and school_grade <= 5 and age <= 25:
        return 6
    elif student_type > 0:
        return 5
    elif worker_type > 0:
        return 2
    elif age >= 65:
        return 3
    else:
        return 4


def get_residence_type(building_type):
    if building_type == 2:
        return 1
    elif building_type == 3:
        return 2
    elif building_type > 3 and building_type <= 9:
        return 3
    elif building_type == 1:
        return 4
    elif building_type == 10:
        return 6
    else:
        return 9


def get_own_or_rent(tenure):
    if tenure < 0:
        return 9
    elif tenure <= 2:
        return 1
    elif tenure == 3:
        return 2
    else:
        return 3


def FormatPersonFile(filename):
    persons = read_population(filename)

    persons["agep"] = persons["agep"].astype(int)
    persons["wkhp"] = persons["wkhp"].astype(float)
    persons["employed"] = persons["employed"].astype(float)
    persons["schg"] = persons["schg"].astype(float)

    worker_type = persons.apply(
        lambda row: get_worker_type(row["employed"], row["wkhp"]),
        axis=1,
    )
    student_type = persons.apply(
        lambda row: get_student_type(row["schg"], row["agep"]),
        axis=1,
    )
    person_type = persons.assign(
        worker_type=worker_type,
        student_type=student_type,
    ).apply(
        lambda row: get_person_type(
            row["agep"],
            row["worker_type"],
            row["wkhp"],
            row["student_type"],
            row["schg"],
        ),
        axis=1,
    )

    output = pd.DataFrame({
        "hhno": persons["hhid"],
        "pno": persons.groupby("hhid", sort=False).cumcount() + 1,
        "pptyp": person_type,
        "pagey": persons["agep"],
        "pgend": persons["sex"],
        "pwtyp": worker_type,
        "pwpcl": -1,
        "pwtaz": -1,
        "pwautime": -1,
        "pwaudist": -1,
        "pstyp": student_type,
        "pspcl": -1,
        "pstaz": -1,
        "psautime": -1,
        "psaudist": -1,
        "puwmode": -1,
        "puwarrp": -1,
        "puwdepp": -1,
        "ptpass": -1,
        "ppaidprk": -1,
        "pdiary": -1,
        "pproxy": -1,
        "psexpfac": 1,
    })
    output.to_csv(
        os.path.join(output_dir, person_out),
        sep=" ",
        index=False,
    )


def FormatHouseholdFile(filename):
    households = read_population(filename)
    crosswalk = pd.read_csv(
        os.path.join(intermediate_dir, "geographicCWalk.csv"),
        dtype={"TAZ": "int", "MAZ": "int"},
    )
    households["taz"] = households["taz"].astype("int")
    households["maz"] = households["maz"].astype("int")
    households = households.merge(
        crosswalk[["TAZ", "MAZ", "TZ_ID"]],
        left_on=["taz", "maz"],
        right_on=["TAZ", "MAZ"],
        how="left",
        validate="many_to_one",
    )
    if households["TZ_ID"].isna().any():
        missing = households.loc[
            households["TZ_ID"].isna(), ["hhid", "taz", "maz"]
        ].iloc[0]
        raise ValueError(
            "No geography match for household {} at TAZ/MAZ ({}, {})".format(
                missing["hhid"], missing["taz"], missing["maz"]
            )
        )

    households["ten"] = pd.to_numeric(households["ten"])
    households["bld"] = pd.to_numeric(households["bld"])
    households["veh"] = pd.to_numeric(households["veh"]).astype(int).clip(lower=0)
    households["hhincadj"] = (
        pd.to_numeric(households["hhincadj"]).round().astype(int).clip(lower=0)
    )

    residence_type = households["bld"].apply(get_residence_type)
    own_or_rent = households["ten"].apply(get_own_or_rent)

    output = pd.DataFrame({
        "hhno": households["hhid"],
        "hhsize": households["np"],
        "hhvehs": households["veh"],
        "hhwkrs": households["nwrkrs_esr"],
        "hhftw": -1,
        "hhptw": -1,
        "hhret": -1,
        "hhoad": -1,
        "hhuni": -1,
        "hhhsc": -1,
        "hh515": -1,
        "hhcu5": -1,
        "hhincome": households["hhincadj"],
        "hownrent": own_or_rent,
        "hrestype": residence_type,
        "hhparcel": households["maz"],
        "hhtaz": households["TZ_ID"],
        "hhexpfac": 1,
        "samptype": 11,
    })
    output.to_csv(os.path.join(output_dir, household_out), index=False)


FormatPersonFile(personFileName)
FormatHouseholdFile(householdFileName)

print("Finished")
