workspace()
using JuMP
using Gurobi


mutable struct node
  xUb
  xLb
  zUb
  zLb
  modelo::JuMP.Model
  status::Symbol
end

mutable struct list
  L::Vector{node}
  Zsup
  Zinf
  xOt
  isup
  solint
end



### meu prob é de max

function mudaparamax(m::Model)
  #muda o c da função objetivo
  if m.objSense == :Min
    @objective(m,:Max,-m.obj)
  end
  return m
end

function testabin(v::Vector,vtype::Vector)
    bin=1
    tam=length(v)
    for i in 1:tam
      if vtype[i] == :Bin
        if v[i]!=0 && v[i]!=1
            bin=0
        end
      end
    end
    return bin
end

function podainv(no::node)
  ###retorna 1 caso positivo (relaxação inviavel, realize a poda) e 0 caso a relaxação seja viavel e prossiga para outros testes
  if no.status == :Optimal
    return 0
  end
  return 1
end

function podaotim(no::node,lista::list)
  vtype = no.modelo.colCat
  if testabin(no.xUb,vtype) == 1
    no.xLb=no.xUb
    no.zLb=no.zUb
    lista.solint = lista.solint + 1
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

function atualizaLupper(lista::list)
  tam=length(lista.L)
  maior=-1e10
  ind=0
  for i in 1:tam
    if lista.L[i].zUb > maior
      maior=lista.L[i].zUb
      ind=i
    end
  end
  lista.Zsup=maior
  lista.isup=ind
end


function bound(no::node,lista::list)
  #retorno 1 se fiz poda, 0 c.c
  if podainv(no) == 1
    return 1
  elseif podaotim(no,lista) == 1 || podalimit(no,lista) == 1
    return 1
  end
  return 0
end

function preencheno(mod::JuMP.Model)
  m=deepcopy(mod)
  status=solve(m, relaxation=true)
  xrel=copy(m.colVal)
  zub=copy(m.objVal)
  no1=node(xrel,[],zub,-1e10,m,status)
  return no1
end

function achamaisfrac(no::node)
  tam=length(no.xUb)
  f=copy(no.xUb)
  vtype = no.modelo.colCat
  for i in 1:tam
    if vtype[i] == :Bin
      teto=ceil(no.xUb[i])
      partefrac=teto-no.xUb[i]
      f[i]=min(partefrac,1-partefrac)
    else
      f[i]=0
    end
  end
  #max,ind=findmax(f)
  return findmax(f)
end

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

function criaretornos(m,obj,xotim,status,tempo,bound,cont,nos,solint)
  m.objVal = copy(obj)
  m.colVal = copy(xotim)
  m.objBound = bound
  m.ext[:time] = tempo
  m.ext[:status] = status
  m.ext[:nodes] = nos
  m.ext[:iter] = cont
  m.ext[:intsols] = solint
  return m
end

function solveMIP(mod)

  tic()

  m=deepcopy(mod)

  #antes de tudo devemos mudar nosso problema para Max
  m=mudaparamax(m)

  #crio o primeio no e dentro dele relaxo o problema
  no1=preencheno(m)

  #vejo se o problema é inviavel
  if podainv(no1) == 1
    model=criaretornos(mod,no1.zLb,no1.xLb,no1.status,0,0,0,0,0)
    if no1.status == :Unbounded
      println("Problema Unbounded")
      return model
    end
    println("Problema inviavel")
    return model
  end
  vtype=no1.modelo.colCat
  #vejo se o problema ja deu a resposta inteira mesmo com a relaxação
  if testabin(no1.xUb,vtype) == 1
    if mod.objSense == :Min
      obj=-no1.zUb
    else
      obj=no1.zUb
    end
    model=criaretornos(mod,obj,no1.xUb,no1.status,0,no1.zUb,0,0,1)
    println("Solução otima encontrada")
    return model
  end

  #como nao é bin nem inviavel podamos (branch), escolho o x mais fracionario para fixar
  #usamos uma lista vazia para inicialização
  listaini=list([],1e10,-1e10,[],0,0)

  #criamos a lista com dois nós
  # esses nós foram originados a partir da fixação do x mais fracionario (em um no fixamos em 0 e no outro o fixamos em 1)

  S=inserefilhos(no1,listaini)

  #agora começa o momento de branch e de bound, perceba que ja fiz o branch então dentro do while começamos com o bound
  #paro quando encontrei uma solução viavel suficientemente proxima da solução da relaxação

  ϵ = abs(S.Zsup - S.Zinf)
  cont=0

  while ϵ > 1e-5 && cont < exp10(4) && length(S.L)!=0

    cont=cont+1

    #seleciono um no para testar o bound
    #a cada 8 vezes escolhendo o no do mesmo ramo (sempre retirando do final da lista), mudo para a esolha do que tem maior upperbound
    #faço isso com o objetivo de não ficar preso em um nó que pode não ser o otimo escolho o que tem maior upper bound pq neste não corro
    #o risco de analisar um nó que possui um upperbound inferior ao da função objetivo
    h=(cont/8)

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

    ϵ = abs(S.Zsup - S.Zinf)
  end

  time=toc()

  if cont >= exp10(4)
    status = :UserLimit
  elseif (S.Zinf < -1e5)
    status = :Infeasible
  else
    status = :Optimal
  end


  if mod.objSense == :Min
    obj=-(S.Zinf)
  else
    obj=S.Zinf
  end
  xotim=S.xOt
  nos=length(S.L)
  model=criaretornos(mod,obj,xotim,status,time,S.Zinf,cont,nos,S.solint)


  return model

end
