#!/usr/bin/python3
# mkhdmenu.py - build an Atari ST (gaming) harddisk image

# Useful info:
# https://people.debian.org/~glaubitz/Atari_HD_File_Sytem_Reference_Guide.pdf
# https://teslabs.com/openplayer/docs/docs/specs/fat16_specs.pdf
# https://averstak.tripod.com/fatdox/dir.htm

# ./mkhdmenu.py 16M "C:\=./ICDBOOT.SYS" "C:\GAMES\BUBLGOST=game_zips/Bubble_Ghost_(Klapauzius).zip" "C:\=./disk" hdd16m.img

# TODO:
# - support variable sector size (bgm)

import sys, os, datetime

from hddimgreader import read_hddimage
from hddimgwriter import write_hddimage
import zipfile

# up to four partitions are currently supported
DRIVES = [ "C:\\", "D:\\", "E:\\", "F:\\" ]

def usage(msg=None):
    if msg: print("Error:", msg)    
    print("Usage mkhdmenu.py [options] <imagename|size> [commands...] [outname]")
    print("Options:")
    print("  -export-bootloader=<name>   if present export bootloaders from MBR and")
    print("                              bootsectors to <name>_mbr.bin and <name>_bootsector.bin")
    print("  -quiet                      print less output")
    print("<imagename|size>              name of existing hdd image to start with or size description")
    print("                              of the individual partitions like e.g. 16M+16384K for two")
    print("                              partitions of 16 megabytes each")
    print("Commands:")
    print("  dest=src                    copy src into the dest path in the image.")
    print("                              Src can be a zip file, a single regular file or")
    print("                              a entire directory like e.g.")
    print("                              C:\\GAMES\\BUBLGOST=zips/Bubble_Ghost.zip")
    print("")
    print("Bootloaders for AHDI and ICD will be installed in the MBR and the bootsector of")
    print("partition C if a file named SHDRIVER.SYS (AHDI) or ICDBOOT.SYS (ICD) is being")
    print("included in partition C. This also works with hddriver and CBHD if they are being")
    print("(re-)named SHDRIVER.SYS")
    
    sys.exit(0)

if len(sys.argv) < 2: usage("No arguments given")    # no arguments at all given ...

# parse all options
options = { "export-bootloader": None, "quiet": False }
arg_idx = 1
while len(sys.argv) > arg_idx and sys.argv[arg_idx][0] == '-':
    # check if option has a "=" in it
    if "=" in sys.argv[arg_idx][1:]:
        name, parm = sys.argv[arg_idx][1:].split("=",1)
    else:
        name = sys.argv[arg_idx][1:]
        parm = None
        
    if not name in options: usage("Unknown option "+sys.argv[arg_idx][1:])

    # options that are not just a boolean take a parameter
    if not isinstance(name, bool):
        if not parm and arg_idx+1 == len(sys.argv):
            usage("Missing option parameter")
        elif parm:
            options[name] = parm
        else:
            options[name] = sys.argv[arg_idx+1]
            arg_idx += 1
    else:
        options[name] = True

    arg_idx += 1

# nothing else remaining?
if len(sys.argv) == arg_idx: usage("Missing <imagename|size> argument")

if not options["quiet"]: print("== mkhdmenu.py ==")
image = sys.argv[arg_idx]
arg_idx += 1

def timestr(time):
    return "{:02d}:{:02d}:{:02d}".format((time>>11)&0x1f,(time>>5)&0x3f,2*(time&0x1f))

def datestr(date):
    return "{:02d}.{:02d}.{:04d}".format(date&0x1f,(date>>5)&0x0f,1980+((date>>9)&0x7f))

######################################################################################
####                                handling files                                ####
######################################################################################

def statistics(partitions):
    def fs_statistics(fs):
        s = { "files":0, "directories":1, "datasize":0 }
        
        for i in fs:
            if "subdir" in i:
                d = fs_statistics(i["subdir"])
                s["files"] += d["files"]
                s["directories"] += d["directories"]
                s["datasize"] += d["datasize"]
            elif "data" in i:
                s["files"] += 1
                s["datasize"] += len(i["data"])

        return s

    print("== Statistics ==")
    
    files = 0
    directories = 0
    datasize = 0
    
    for i in partitions:
        s = fs_statistics(i["files"])
        files += s["files"]
        directories += s["directories"]
        datasize += s["datasize"]

    print("Total number of directories:     ", directories)
    print("Total number of files:           ", files)
    print("Total data bytes:                ", datasize)

def dump_trees(partitions):
    # TODO: determine max depth first and adjust size offset dynamically
    
    def dump_tree(prefix, fs):
        for f in fs:
            if "subdir" in f:
                print(prefix+f["name"]+"\\")
                dump_tree(prefix+"  ", f["subdir"])
            else:
                print(prefix+f["name"], (" "*24)[:-len(f["name"]+prefix)-len(str(len(f["data"])))], len(f["data"]), " ", timestr(f["time"]), " ", datestr(f["date"]))

    for i in range(len(partitions)):
        print("== Files on partition",DRIVES[i],"==")
        dump_tree("", partitions[i]["files"])

# check if image is actually a size description like 16M+16M+8M
parts = image.split("+")
# check all parts for being numbers or numbers+"M" or numbers+"K"
is_size = True
for p in parts:
    if not ((p[-1] == 'M' or p[-1] == 'K') and len(p) > 1 and p[:-1].isnumeric()) and not p.isnumeric():
        is_size = False

# is a valid size desciption -> setup empty partitions scheme
if is_size:
    partitions = []
    for p in parts:
        if p[-1] == 'M': size = int(p[:-1]) * 1048576
        elif p[-1] == 'K': size = int(p[:-1]) * 1024
        else: size = int(p)

        if size > 16*1024*1024:
            print("Error, partition size must be 16 Megabytes at most")
            sys.exit(-1)
        
        if size & 511:
            print("Error, partition size must be a multiple of 512")
            sys.exit(-1)
        
        partitions.append( {"size":size//512, "files": [] }  )        
else:   
    # read given image into memory
    partitions = read_hddimage(image, options)

if not partitions: sys.exit(-1)

# ========= this is the moment to modify the data =========
# - add files and directories
# - add bootloader
# - redo FAT

def get_file(flist, name):
    for f in flist:
        if f["name"] == name:            
            return f

        if "subdir" in f:
            h = get_file(f["subdir"], name)
            if h: return h
        
    return None
    
def add_file(files, file):
    # process path ...
    for p in file["name"].split("\\")[:-1]:
        d = get_file(files, p)
        if not d:            
            # create directory if it doesn't exist yet
            d = { "name": p, "subdir": [], "time": file["time"], "date": file["date"] }
            files.append(d)

        if not "subdir" in d:
            print("Error, is not a directory", p)
            return False
            
        files = d["subdir"]

    # ... and add the file itself
    file["name"] = file["name"].split("\\")[-1]

    index = None
    # check if the file already exists
    for i in range(len(files)):
        if files[i]["name"] == file["name"]:
            index = i

    if index != None:
        files[index] = file
    else:    
        files.append(file)
    
    return True
    
def import_zip(drive, partition, src, dst):
    try:            
        archive = zipfile.ZipFile(src, 'r')
    except Exception as e:
        print(str(e))
        return False

    # make sure destination ends with a "\" as we are
    # importing whole directories
    if not dst[-1] == "\\": dst = dst + "\\"

    for filename in archive.namelist():
        print("Creating", drive+dst+filename)
        with archive.open(filename) as f:
            dt = archive.getinfo(filename).date_time
            ftime = (dt[3] << 11) + (dt[4] << 5) + dt[5]//2
            fdate = dt[2] + (dt[1] << 5) + ((dt[0]-1980)<<9)
            file = { "name": dst.upper()+filename.upper(), "data": f.read(), "time": ftime, "date":fdate }
            if not add_file(partition, file):
                return False

    return True

def import_directory(drive, partition, src, dst):
    def import_dir(drive, partition, src, dst):
        with os.scandir(src) as entries:
            dst_path = dst.upper()
            if len(dst_path): dst_path += "\\"

            for entry in entries:
                if entry.is_file():
                    import_file(drive, partition, src + "/" + entry.name, dst_path + entry.name.upper())                    

                elif entry.is_dir():
                    import_dir(drive, partition, src+"/"+entry.name, dst_path + entry.name.upper())

    if len(dst) and dst[-1] == "\\": dst = dst[:-1]
    src = os.path.normpath(src)
    
    import_dir(drive, partition, src, dst)
        
    return True
    
def import_file(drive, partition, src, dst):
    try:            
        f = open(src, 'rb')
    except Exception as e:
        print(str(e))
        return False

    # if the target ends with "\" then it's clear that a directory
    # is meant and we just append the source name to make it the full
    # target file name
    if not dst:
        dst = src.split("/")[-1].upper()    
    elif dst[-1] == "\\":
        dst = dst + src.split("/")[-1].upper()
    else:
        # check if destination exists and is a directory
        i = get_file(partition, dst)
        if i and "subdir" in i:
            dst = dst + "\\" + src.split("/")[-1].upper()

    print("Creating", drive+dst)

    dt = datetime.datetime.fromtimestamp(os.stat(src).st_mtime, tz=datetime.timezone.utc)
    ftime = (dt.hour << 11) + (dt.minute << 5) + dt.second//2
    fdate = dt.day + (dt.month << 5) + ((dt.year-1980)<<9)

    file = { "name": dst.upper(), "date": fdate, "time": ftime, "data": f.read() }
    f.close()
    
    return add_file(partition, file)
    
def import_item(partitions, src, dst):
    print("Import", src, "to", dst)
        
    if not dst[:3] in DRIVES:
        print("Error, not a valid partition")
        return False

    if DRIVES.index(dst[:3]) > len(partitions):
        print("Error, partition not present")
        return False

    # select the right partition
    partition = partitions[DRIVES.index(dst[:3])]["files"]
    drive = dst[:3]
    dst = dst[3:]
    
    # handle the various sources
    if os.path.isfile(src) and src.lower().endswith(".zip"):
        return import_zip(drive, partition, src, dst)
    elif os.path.isdir(src):
        return import_directory(drive, partition, src, dst)
    elif os.path.isfile(src):
        return import_file(drive, partition, src, dst)
    else:
        print("Error, don't know how to import", src)
        
    return False

def mk_csv(partitions):
    def csv_scan(files, parent):
        gamelist = [ ]
        for f in files:
            if "subdir" in f:
                sublist = csv_scan(f["subdir"], f["name"])
                for entry in sublist:
                    gamelist.append(f["name"]+"\\"+entry)
                
            else:            
                if parent and parent == f["name"].split(".")[0] and f["name"].split(".")[-1] == "PRG":
                    gamelist.append(f["name"])

        return gamelist
    
    # search for games. All programs following the pattern
    # GAME/GAME.PRG are considered being games
    print("Creating game list in C:\\HDMENU.CSV...")
    
    csv = bytearray()
    for p in range(len(partitions)):
        plist = csv_scan(partitions[p]["files"], None)
        for i in plist:
            print("Found game", DRIVES[p] + i)
            csv = csv + i.split("\\")[-1].split(".")[0].encode("latin-1")
            csv = csv + (";"+DRIVES[p]).encode("latin-1")
            csv = csv + i.encode("latin-1")
            csv = csv + "\r\n".encode("latin-1")

    if csv:
        dt = datetime.datetime.now()
        ftime = (dt.hour << 11) + (dt.minute << 5) + dt.second//2
        fdate = dt.day + (dt.month << 5) + ((dt.year-1980)<<9)

        partitions[0]["files"].append( { "name": "HDMENU.CSV", "time":ftime, "date":fdate, "data":csv } )
    else:
        print("Warning, no games found, creating no HDMENU.CSV")
            
        # print("Games:", csv)

# scan over any further argument until the last one
while arg_idx < len(sys.argv)-1:
    cmd = sys.argv[arg_idx]

    # argument may be like
    if cmd[:3] in DRIVES:
        # convert any \ to / to simplify work        
        dst, src = cmd.split("=",1)        
        dst = dst.replace("/", "\\")

        if not import_item(partitions, src, dst):
            sys.exit(-1)
    else:
        print("Error, unknown command", cmd)
        sys.exit(-1)
        
    arg_idx += 1

mk_csv(partitions)
    
if not options["quiet"]:
    # dump the fs trees
    dump_trees(partitions)

    # do some fs statistics
    statistics(partitions)
    
# write the entire disk image into a file
if arg_idx == len(sys.argv)-1:
    write_hddimage(sys.argv[-1], partitions, options)
