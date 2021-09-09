import shutil, os

doExport = True

if doExport:
    os.chdir(loc := os.path.dirname(__file__))
    if os.path.isdir("aebalExport"):
        shutil.rmtree(f"aebalExport")
    if os.path.isfile("aebal.zip"):
        os.remove("aebal.zip")
    os.system(f"""processing-java --sketch={loc}/aebal --output={loc}/aebalExport --export --platform windows""")
    shutil.rmtree(f"aebalExport/source")
    shutil.copytree("gameSongs", songDir := "aebalExport/songs")
    shutil.copytree("aebal/assets", assetDir := "aebalExport/assets")
    shutil.make_archive("aebal", 'zip', "aebalExport")
    # shutil.rmtree(f"aebalExport")

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

# print(f"Code Files:"+'\n\t'.join([''] + fileList))

print("Line count:", len(list(filter(lambda x: len(x.strip()), sum((open(i, 'r').read().split('\n') for i in fileList), [])))))