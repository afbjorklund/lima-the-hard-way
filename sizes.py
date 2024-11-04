import sys
import os

import humanize
import matplotlib.pyplot as plt

lines = open(sys.argv[1]).read().splitlines()
output = sys.argv[2]


def parse(string):
    return int(k) * 1024


def format(size):
    return humanize.naturalsize(size, True)


total = 0

values = []
labels = []
for line in lines:
    k, f = line.split()
    size = parse(k)
    filename = f.endswith("gz") and f or f + "*"
    label = "%s (%s)" % (filename, format(size))
    labels.append(label)
    values.append(size)
    total += size

plt.figure(figsize=(12.0, 9.0))
plt.pie(values, labels=labels, autopct="%1.1f%%", shadow=True, startangle=0)
# Set aspect ratio to be equal so that pie is drawn as a circle.
plt.axis("equal")

plt.suptitle("Disk size per file", fontsize=24)
plt.subplots_adjust(left=0.25, right=0.75, top=0.85)
plt.title("Total size: " + format(total), fontsize=14)
plt.annotate("* executable", xy=(0.0, -1.2))

plt.savefig(output)
