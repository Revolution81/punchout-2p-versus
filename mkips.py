import sys
a=open(sys.argv[1],'rb').read(); b=open(sys.argv[2],'rb').read()
assert len(a)==len(b)
out=bytearray(b'PATCH'); i=0
while i<len(a):
    if a[i]!=b[i]:
        j=i
        while j<len(a) and j-i<0xFFFF and (a[j]!=b[j] or (j+1<len(a) and a[j+1]!=b[j+1])): j+=1
        assert i!=0x454F46
        out+=i.to_bytes(3,'big')+(j-i).to_bytes(2,'big')+b[i:j]; i=j
    else: i+=1
out+=b'EOF'; open(sys.argv[3],'wb').write(out)
print('ips bytes',len(out))
