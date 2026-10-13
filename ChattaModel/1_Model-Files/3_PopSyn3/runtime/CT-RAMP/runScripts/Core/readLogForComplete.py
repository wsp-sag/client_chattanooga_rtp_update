import re

f = open("console_MainABM_PreMC.log", 'rb').read()
text = f.decode('utf-16')
nlines = 0
for line in text.splitlines(): #
	if nlines == 0:
		mm = re.search('([0-9]{2}-[A-Za-z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}).*', line)
		if mm != None:
			print("Model started at {0}".format(mm.group(1)))
	mm = re.search('([0-9]{2})-([A-Za-z]{3})-([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*end of task.*', line)
	if mm != None:
		print(mm.group(0))
	mm = re.search('.*Model started.*', line)
	if mm != None:
		print(mm.group(0))
	mm = re.search('([0-9]{2})-([A-Za-z]{3})-([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*completed.*', line)
	if mm != None:
		print(mm.group(0))
	nlines += 1
	mm = re.search('([0-9]{2}-[A-Za-z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}).*[0-9]{1,6}.*seconds.', line)
	if mm != None:
		print(mm.group(0))