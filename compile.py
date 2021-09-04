import os, shutil

os.chdir(loc := os.path.dirname(__file__))
if os.path.isdir("aebalExport"):
    shutil.rmtree(f"aebalExport")
os.system(f"""processing-java --sketch={loc}/aebal --output={loc}/aebalExport --export --platform windows""")
shutil.rmtree(f"aebalExport/source")
shutil.copytree("gameSongs", songDir := "aebalExport/songs")
shutil.copytree("aebal/assets", assetDir := "aebalExport/assets")
shutil.make_archive("aebal", 'zip', "aebalExport")
shutil.rmtree(f"aebalExport")