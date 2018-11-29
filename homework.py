from random import randint


with open('num_set.csv','w') as f:
    for _ in range(1,100+1):
        num1=randint(1,1000)  #randrange(1,1000+1)
        num2=randint(1,1000)
        num_set=(num1,num2)
        #print(num_set)
        f.write("{num1},{num2}\n".format(
            num1=num_set[0], num2=num_set[1]))



with open('num_set.csv','r') as f:
    lines = f.readlines()
    
    with open('result.csv','w') as g:
        for line in lines:
            splited=[int(item) for item in line.split(',')]
            result=splited[0]*splited[1]
            g.write("{num1},{num2},{result}\n".format(
                num1=splited[0],
                num2=splited[1],
                result=result
            ))
