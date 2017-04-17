-- simple table constructor
a={3,42,1+2+3};
print(a[3-1+1+({-1})[1]])

-- simple content modification
a[1] = a[1] + 1
print(a[1])

a[3], a[2], a[1] = a[1], a[2], a[3]
print(a[1], a[2], a[3])
