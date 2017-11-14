workspace()
using JuMP
using Gurobi


mutable struct node
  xUb::Vector{Float64}
  xLb::Vector{Int}
  zUb::Float64
  zLb::Int
  modelo::JuMP.Model
  status::Symbol
end

mutable struct list
  L::Vector{node}
  Zsup
  Zinf
  xOt
  isup
end



### meu prob é de max
#testei
function mudaparamax(m::Model)
  #muda o c da função objetivo
  if m.objSense == :Min
    @objective(m,:Max,-m.obj)
  end
  return m
end

#testei
function podainv(no::node)
  ###retorna 1 caso positivo (relaxação inviavel, realize a poda) e 0 caso a relaxação seja viavel e prossiga para outros testes
  if no.status == :Optimal
    return 0
  end
  return 1
end
#testei
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
#testei (algo estranho acontece quando defino zinf, preciso fazer a listaini de novo)
function podalimit(no::node,lista::list)
  if no.zUb < lista.Zinf
    return 1
  end
  return 0
end
#testei
function atualizaLupper(lista::list)
  tam=length(lista.L)
  maior=-1e10
  ind=0
  for i in 1:tam
    if lista.L[i].zUb > maior
      maior=lista.L[i].zUb
      #ind=i
    end
  end
  lista.Zsup=maior
  lista.isup=ind
end
#testei
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

#duvida se uso o "ou", só uso se a função parar assim que encontra uma resposta positiva
#testei
function bound(no::node,lista::list)
  if podainv(no) == 1 || podaotim(no,lista) == 1 || podalimit(no,lista) == 1
    return 1
  end
  return 0
end

#testei
function preencheno(mod::JuMP.Model)
  m=deepcopy(mod)
  status=solve(m, relaxation=true)
  xrel=copy(m.colVal)
  zub=copy(m.objVal)
  no1=node(xrel,[],zub,-1e10,m,status)
  return no1
end

#testei
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

#testei
function inserefilhos(no::node,S::list)

  max,ind=achamaisfrac(no)

  mod1=deepcopy(no.modelo)
  mod1.colLower[ind]=1
  mod1.colUpper[ind]=1
  filho1=preencheno(mod1)

  mod2=deepcopy(no.modelo)
  mod2.colLower[ind]=0
  mod2.colUpper[ind]=0
  filho2=preencheno(mod2)

  push!(S.L,filho1,filho2)

  atualizaLupper(S)

  return S
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

  #como nao é bin nem inviavel podamos (branch), escolho o x mais fracionario para fixar
  #usamos uma lista vazia para inicialização
  listaini=list([],1e10,-1e10,[],0)

  #criamos a lista com dois nós
  # esses nós foram originados a partir da fixação do x mais fracionario (em um no fixamos em 0 e no outro o fixamos em 1)

  S=inserefilhos(no1,listaini)

  #agora começa o momento de branch e de bound, perceba que ja fiz o branch então dentro do while começamos com o bound
  #paro quando encontrei uma solução viavel suficientemente proxima da solução da relaxação

  ϵ = abs(S.Zsup - S.Zinf)
  cont=0

  while ϵ > 1e-5 && cont < 1e3

    cont=cont+1

    #seleciono um no para testar o bound
    #a cada 5 vezes escolhendo o no do mesmo ramo (sempre retirando do final da lista), mudo para a esolha do que tem maior upperbound
    #faço isso com o objetivo de não ficar preso em um nó que pode não ser o otimo escolho o que tem maior upper bound pq neste não corro
    #o risco de analisar um nó que possui um upperbound inferior ao da função objetivo
    h=(cont/5)

    if floor(h) == h
      no=S.L[S.isup]
      deleteat!(S.L,S.isup)
    else
      no=pop!(S.L)
    end

    devobound=bound(no,S)
    #a função bound atualiza o lowerbound no caso de poda por otimalidade

    if devobound == 1
      #atualizo o upperbound com os novos elementos e volto pro loop para escolher outro nó para analisar
      atualizaLupper(S)

    else
      #como não consegui podar o ramo que contém esse nó devo fazer o branch do no o separando em 2 e fixando na variavel mais fracionaria
      S=inserefilhos(no,S)
      #a inserefilhos ja atualiza os bounds
    end
  end
































  n=S.L
  if podainv(n) == 1 || podaotim(n,lista) == 1 || podalimit(n,lista) == 1
    pop!(lista)
  end


#### quando atualizo op lb tenho que tirar da lista td mundo q tem um up menor que ele
