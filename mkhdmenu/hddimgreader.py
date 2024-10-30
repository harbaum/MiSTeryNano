# hdimgreader.py - quick'n dirty code to read an entire Atari ST harddisk image
#
# This does a bunch of sanity checks while loading but will finally only return
# the contents of the partitions

# Useful info:
# https://people.debian.org/~glaubitz/Atari_HD_File_Sytem_Reference_Guide.pdf
# https://teslabs.com/openplayer/docs/docs/specs/fat16_specs.pdf
# https://averstak.tripod.com/fatdox/dir.htm

import struct

def load_image(name):
    print("Loading",name,"...")
    
    try:
        img = []
        with open(name, "rb") as f:
            # read into array of sectors
            d = f.read(512)
            while len(d) == 512:
                img.append(d)
                d = f.read(512)

            if len(d) != 0:
                print("Warning: Image size is not a multiple of 512")
                
            f.close()
            return img
    except Exception as e:
        print(str(e))

    return None

def check_csum(sec, s=0x1234):
    csum = 0
    for i in range(256): csum = (csum + struct.unpack(">H", sec[2*i:2*i+2])[0]) & 0xffff
    return csum == s
    
def hdd_img_parse(img, options):
    # parse the mbr
    if not options["quiet"]: print("== MBR ==")
    mbr = img[0]

    # optional bootloader
    hdd = { }
    hdd["mbr"] = { }

    # extract bootloader code if present
    if check_csum(mbr):
        if not options["quiet"]: print("MBR contains a bootloader")
        hdd["mbr"]["bootloader"] = mbr[0:0x1c2]

        if options["export-bootloader"]:
            print("Exporting to", options["export-bootloader"]+"_mbr.bin")
                        
            # export bootloader into seperate file
            try:
                with open(options["export-bootloader"]+"_mbr.bin", "wb") as f:
                    f.write(hdd["mbr"]["bootloader"])
                    f.close()
            except Exception as e:
                print(e)
        
    hdd["mbr"]["hd_siz"] = struct.unpack(">L", mbr[0x1c2:0x1c6])[0]
    print("Total disk size in sectors:", hdd["mbr"]["hd_siz"])

    if hdd["mbr"]["hd_siz"] != len(img):
        print("Warning, size != image length (",len(img),")")

    # parse the four partition entries
    hdd["partition"] = [ ]
    hdd["mbr"]["partition"] = [ ]
    for i in range(4):
        entry = mbr[0x1c6+12*i:0x1c6+12*(i+1)]

        p = { }
        p["flags"], p["id"], p["start"], p["length"] = struct.unpack(">B3sLL", entry)
 
        if p["flags"] & 1:
            # partition exists
            p["id"] = p["id"].decode("latin-1")
            print("Partition", i, "ID:", p["id"], "Start:", p["start"], "Length:", p["length"], "bootable" if p["flags"] & 0x80 else "")

            # check if partition data is within disk image
            if p["start"] + p["length"] > len(img):
                print("Error, partition exceeds image length by",p["start"] + p["length"]-len(img),"sectors")
                return None

            hdd["mbr"]["partition"].append(p)
            hdd["partition"].append(img[p["start"]:p["start"] + p["length"]])

    # check if there are any partitions at all
    if not hdd["mbr"]["partition"]:
        print("Error, no valid partition entries")
        return None
            
    # check if there's unused space after last partition
    if hdd["mbr"]["partition"][-1]["start"] + hdd["mbr"]["partition"][-1]["length"] < len(img):
        print("Warning: Unallocated",len(img) - (hdd["mbr"]["partition"][-1]["start"] + hdd["mbr"]["partition"][-1]["length"]),"sectors")

    return hdd

def parse_fat16(part, data):
    
    # create a list of all FATs
    fats = []
    
    # parse each FAT
    for p in range(part["nfats"]):
        fat = []
        for i in range(part["spf"]):        
            fsec = data[i+part["spf"]*p]

            # each 512 byte sector contains 256 FAT16 entries
            v = struct.unpack("<256H", fsec)
            fat.extend(v)

        fats.append(fat)                            

    # check if all fats are the same and bail out if not
    if len(fats) > 1:
        for p in range(1,len(fats)):
            if fats[0] != fats[p]:
                print("Error, FATs", 0,"and", p,"differ!")
                return None

    # continue with one fat only
    print("Total number of FAT entries:     ", len(fat))

    # check if the FAT is big enough
    clusters_needed = (len(data)+part["spc"]-1) // part["spc"]
    if clusters_needed > len(fat):
        print("Error, not enough FAT entries,",clusters_needed,"needed")
        return None

    # fat entries 0 and 1 should be fff8 and ffff
    if fat[0] != 0xfff8 or fat[1] != 0xffff:
        print("Warning, illegal FAT entries 0/1", hex(fat[0]), hex(fat[1]))

    # create a "reverse" FAT containing a the cluster referencing
    # the given one
    rev_fat = [None for x in range(len(fat))]
    for i in range(len(fat)):
        if fat[i] > 0 and fat[i] < len(fat):
            # there must not already be a reference as a cluster may
            # never be part of two files or directories
            if rev_fat[fat[i]] != None:
                print("Error, doubly referenced cluster", i, "in FAT", p)
                return None
            
            rev_fat[fat[i]] = i

    # scan for cluster chains
    chains = { }
    for i in range(2, len(fat)):
        # check for clusters that are used but not referenced by any other cluster

        # start clusters are allocated clusters which are not referenced by another cluster
        if fat[i] and rev_fat[i] == None:
            #  print("Cluster",i,"is a start cluster")

            # build the cluster chain
            chains[i] = []
            n = i
            while fat[n] < 0xfff0:
                chains[i].append(fat[n])
                n = fat[n]

#    for i in chains:
#        print("Chain:", i, chains[i])

    part["chains"] = chains
    return part

def get_data(cluster, fat, data_sectors):
    def get_cluster_data(cluster, fat, data_sectors):
        data = bytearray()
        for i in range(fat["spc"]):
            data += data_sectors[fat["spc"]*(cluster-2)+i]

        return data
            
    if not cluster in fat["chains"]:
        print("Error, file/dir cluster", cluster, "does not point to a cluster chain")
        return None

    # get first data cluster
    data = get_cluster_data(cluster, fat, data_sectors)

    # append data from cluster chain
    for c in fat["chains"][cluster]:
        data += get_cluster_data(c, fat, data_sectors)

    return data

def parse_directory(path, dir_data, fat, data_sectors):
    FLAG_RO = 0x01
    FLAG_HIDDEN = 0x02
    FLAG_SYSTEM = 0x04
    FLAG_VOLNAME = 0x08
    FLAG_DIRECTORY = 0x10
    FLAG_ARCHIVE = 0x20
    
    # split dirctory data into individual entries
    dir_entries = []
    for index in range(len(dir_data)//32):
        entry_data = dir_data[index*32:(index+1)*32]
        if entry_data[0] != 0xe5 and entry_data[0] != 0:
            # parse one directory entry
            entry = { }
            name, ext, entry["attr"], entry["time"], entry["date"], entry["cluster"], entry["size"] = struct.unpack("<8s3sB4x6xHHHL", entry_data)

            # decode 8.3 file name
            entry["name"] = name.decode("latin-1").rstrip(" ")
            ext = ext.decode("latin-1").rstrip(" ")
            if ext != "": entry["name"] += "."+ext 

            # normal directories have only the directory flag set
            if entry["attr"] == FLAG_DIRECTORY:
                # don't scan '.' or '..'
                if entry["name"] != "." and entry["name"] != "..":
                    data = get_data(entry["cluster"], fat, data_sectors)
                    if not data:
                        print("Error getting directory data for", entry["name"])
                        return None
                    
                    subdir = parse_directory(path + entry["name"] + "/", data, fat, data_sectors)
                    if subdir == None: return None                    
                    entry["subdir"] = subdir
                    dir_entries.append(entry)

            # regular files have neither the directory nor the volume nor the system flag set
            # ignore hidden, archive and ro flags
            elif entry["attr"] & ~(FLAG_RO | FLAG_ARCHIVE | FLAG_HIDDEN) == 0:
                data = get_data(entry["cluster"], fat, data_sectors)
                if not data:
                    print("Error getting file data for", entry["name"])
                    return None
                
                # check if there's enough data
                if len(data) < entry["size"]:
                    print("Error, not enough data for specified file length in", path + entry["name"])
                    return None
                    
                # truncate to file length
                entry["data"] = data[:entry["size"]]
                dir_entries.append(entry)

            elif entry["attr"] == FLAG_VOLNAME:
                if path != "/": print("Warning, volume name in non-rootdir")
                    
            elif entry["attr"] == 0x0f:
                print("Warning, ignoring what seems to be a VFAT entry in", path)
                
            else:                
                print("Warning, unexpected flags, ignoring file entry in", path)

    return dir_entries
                
def partition_parse(img, options):
    print("Size", len(img))

    # check partition boot sector
    bootsec = img[0]
    
    part = { }

    # decode little endian (x86) format
    part["bra_s"] = struct.unpack(">H", bootsec[0:2])[0]
    part["filler"], part["serial"], part["bps"], part["spc"], part["res"] = struct.unpack("<6s3sHBH", bootsec[2:16])
    print("BRA.S:                           ", hex(part["bra_s"]))
    print("Filler:                          ", ' '.join('{:02x}'.format(x) for x in part["filler"]))
    print("Serial:                          ", ' '.join('{:02x}'.format(x) for x in part["serial"]))
    print("Bytes per sector:                ", part["bps"])
    print("Sectors per cluster:             ", part["spc"])
    print("Reserved:                        ", part["res"])
    part["nfats"], part["ndirs"], part["nsects"], part["media"], part["spf"], part["spt"], part["nsides"], part["nhid"] = struct.unpack("<BHHBHHHH", bootsec[16:30])
    print("Number of FATs:                  ", part["nfats"])
    print("Number of root directory entries:", part["ndirs"])
    print("Total number of sectors:         ", part["nsects"])
    print("Media byte:                      ", hex(part["media"]))
    print("Sectors per FAT:                 ", part["spf"])
    print("Sectors per track:               ", part["spt"])
    print("Number of sides:                 ", part["nsides"])
    print("Hidden sectors:                  ", part["nhid"])

    # read reserved sectors as they may contain parts of the hdd driver
    # the first reserved sector is actually the bootsector itself which is being saved, anyway,
    # if it's bootable
    if part["res"] > 1: part["reserved"] = img[1:part["res"]]
    
    # check for bootloader
    if check_csum(bootsec):
        if not options["quiet"]: print("Partition bootsector contains a bootloader")
        part["bootloader"] = bootsec

        if options["export-bootloader"]:
            print("Exporting to", options["export-bootloader"]+"_bootsector.bin")
                        
            # export bootloader into seperate file
            try:
                with open(options["export-bootloader"]+"_bootsector.bin", "wb") as f:
                    f.write(part["bootloader"])
                    f.close()
            except Exception as e:
                print(e)
        
    
    # do various checks
    if part["res"] < 1: print("Error, reserved sectors must at least be 1")
    if part["bps"] != 512: print("Warning, sector size != 512")
    if part["media"] != 0xf8: print("Warning, media byte should be 0xf8 for hard disks")
    if part["nsects"] != len(img): print("Warning, number of sectors mismatch")
    if part["spt"]: print("Warning, sectors per track should be 0 for hard disks")
    if part["nsides"]: print("Warning, number of sides should be 0 for hard disks")
    if part["nfats"] != 2: print("Warning, number of FATs should be 2")
    if part["ndirs"] % 32: print("Warning, number of root directory entries is not a multiple of 32")
    
    # get data area
    data = img[part["res"]+part["nfats"]*part["spf"]+part["ndirs"]//16:]
    
    # parse the fat
    fat = parse_fat16(part, img[part["res"]:part["res"]+part["nfats"]*part["spf"]])
    if not fat: return None

    # scan the entire filesystem, starting with the root directory
    root_dir_start = part["res"]+part["nfats"]*part["spf"]
    root_dir = bytearray()
    for i in range(part["ndirs"]//16): root_dir += img[root_dir_start+i]
    fs = parse_directory("/", root_dir, fat, data)
    if fs == None: return None

    # return partition info
    return { "fat":fat, "fs": fs, "info":part }

def partitions_parse(hdd, options):
    # check all partitions
    partitions = []

    for i in range(len(hdd["partition"])):
        if hdd["mbr"]["partition"][i]["id"] == "GEM":    
            print("== Partition", i, "==")
            partition = partition_parse(hdd["partition"][i], options)
            if not partition: return None
            partitions.append(partition)
        else:
            print("Skipping unknown partition type", i)

    return partitions

def read_hddimage(name, options):
    hdd_img = load_image(name)
    if not hdd_img: return None

    print("Image contains", len(hdd_img), "sectors (",len(hdd_img)*512,"bytes)")

    # convert into individual partitions
    hdd = hdd_img_parse(hdd_img, options)
    if not hdd: return None

    partitions = partitions_parse(hdd, options)

    # drop everythig but the minimum partition info needed
    for i in range(len(partitions)):
        # all we need to know is the size of each partition and the
        # files/directories to be stored there
        pinfo = {}
        pinfo["size"] = partitions[i]["info"]["nsects"]        
        pinfo["files"] = partitions[i]["fs"]
        partitions[i] = pinfo
    
    return partitions

