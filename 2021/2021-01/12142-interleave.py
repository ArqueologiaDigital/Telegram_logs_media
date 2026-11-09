file1 = open("cmp2ks.evn_rev_6.1.u20", "rb").read()
file2 = open("cmp2ks.odd_rev_6.1.u13", "rb").read()

output = open("output.rom", "w+")
for addr in range(len(file1)):
    output.write(chr(file1[addr]))
    output.write(chr(file2[addr]))

