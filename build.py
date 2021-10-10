import shutil, os
from datetime import datetime

doExport = True

fileList = []
def checkFolder(path, rec = True):
    for i in os.listdir(path):
        fileName = path + '/' + i
        if os.path.isfile(fileName):
            if os.path.splitext(fileName)[1][1:] in ["pde", "glsl", "md", "gitignore", "py"]:
                fileList.append(fileName)
        elif os.path.isdir(fileName) and rec:
            checkFolder(fileName)

checkFolder(f"{os.path.dirname(__file__)}/aebal")
checkFolder(f"{os.path.dirname(__file__)}", False)

print("Line count:", len(list(filter(lambda x: len(x.strip()), sum((open(i, 'r').read().split('\n') for i in fileList), [])))))

if doExport:
    buildName = "build_{:%Y-%m-%d_%H-%M-%S}".format(datetime.now())
    os.chdir(loc := os.path.dirname(__file__))
    if os.path.isdir("aebalExport"):
        shutil.rmtree(f"aebalExport")
    if os.path.isfile("aebal.zip"):
        os.remove("aebal.zip")
    os.system(f"""processing-java --sketch={loc}/aebal --output={loc}/aebalExport --export --platform windows""")
    shutil.rmtree(f"aebalExport/source")
    shutil.copytree("gameSongs", songDir := "aebalExport/songs")
    shutil.copytree("aebal/assets", assetDir := "aebalExport/assets")
    shutil.copyfile("aebal/patterns.json", "aebalExport/patterns.json")
    print("Creating archive...")
    shutil.make_archive("aebal", 'zip', "aebalExport")
    print("Finished making archive.")
    
    if os.path.isdir(f"{buildName}"):
        shutil.rmtree(f"{buildName}")
    os.mkdir(buildName)
    
    shutil.move("aebalExport", f"{buildName}/aebal")
    os.rename("aebal.zip", f"{buildName}/aebal.zip")
    
    # shutil.rmtree(f"aebalExport")