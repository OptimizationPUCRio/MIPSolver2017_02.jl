workspace()
using JuMP
using Gurobi


mutable struct node
  xUb::Vector{Float64}
  xLb::Vector{Int}
  zUb::Float64
  zLb::Int
  problema::JuMP.Model
  status::Symbol
end

mutable struct list
  L::Vector{node}
  Zsup
  Zinf
  xOt
end



### meu prob é de max
function mudaparamax(m::Model)
  #muda o c da função objetivo
  if m.objSense == :Min
    @objective(m,:Max,-m.obj)
  end
  return m
end

#ainda vou mudar essa poda
function podainv(no::node)
  ###retorna 1 caso positivo (relaxação inviavel, realize a poda) e 0 caso a relaxação seja viavel e prossiga para outros testes
  if no.status == :Optimal
    return 0
  end
  return 1
end
function podaotim(no::node,lista::list)
  if testabin(no.xUb) == 1
    no.xLb=no.xUb
    if lista.Zinf < no.zUb
      lista.Zinf = no.zUb
      lista.xOt = no.xUb
    end
    return 1
  end
  return 0
end
function podalimit(no::node,lista::list)
  if no.zUb < lista.Zinf
    return 1
  end
  return 0
end
function atualiza(lista::list)
  tam=length(lista.L)
  maior=-1e10
  #ind=0
  for i in 1:tam
    if lista.L[i].zUb > maior
      maior=lista.L[i].zUb
      #ind=i
    end
  end
  lista.Zsup=maior
  #lista.isup=ind
end
function testabin(v::Vector)
    bin=1
    tam=length(v)
    for i in 1:tam
        if v[i]!=0 && v[i]!=1
            bin=0
        end
    end
    return bin
end

function branch (no::node,lista::list)

  if podainv(no) == 1 ||
    return 1
  end
  if podaotim(no,lista)

function preencheno(mod::JuMP.Model)
  m=deepcopy(mod)
  status=solve(m, relaxation=true)
  xrel=copy(m.colVal)
  zub=copy(m.objVal)
  no1=node(xrel,[],zub,-1e10,prob,status)
  return no1
end

function achamaisfrac(no::node)
  tam=length(no.xUb)
  f=copy(no.xUb)
  for i in 1:tam
    piso=floor(no.xUb[i])
    partefrac=piso-no.xUb[i]
    f[i]=min(partefrac,1-partefrac)
  end
  #max,ind=findmax(f)
  return findmax(f)
end


function MILPSolver(m)

  #antes de tudo devemos mudar nosso problema para Max
  m=mudaparamax(m)

  #crio o primeio no e dentro dele relaxo o problema
  no1=preencheno(m)

  #vejo se o problema é inviavel
  if podainv(no1) == 1
    println("Problema inviavel")
    return no1.status,no1.xRel
  end

  #vejo se o problema ja deu a resposta inteira mesmo com a relaxação
  if testabin(no1.xUb) == 1
    println("Solução otima encontrada")
    return no1.status,no1.xRel
  end

  #como nao é bin nem inviavel podamos, escolho o x mais fracionario
  xfrac,posfrac=achamaisfrac(no1)

  #criamos então a lista com os dois nós originados a partir do x mais fracionario (em um no o fixamos em 0 e no outro o fizamos em 1)

  S=list([no1],no1.zUb,no1.zLb,[])

  if branch(list)==1







  n=S.L
  if podainv(n) == 1 || podaotim(n,lista) == 1 || podalimit(n,lista) == 1
    pop!(lista)
  end


#### quando atualizo op lb tenho que tirar da lista td mundo q tem um up menor que ele
