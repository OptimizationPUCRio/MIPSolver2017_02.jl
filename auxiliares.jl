workspace()
using JuMP
using Gurobi


mutable struct node
  xUb::Vector{Float64}
  xLb::Vector{Int}
  zUb::Float64
  zLb::Int
  xRel
  mod::JuMP.Model
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


#ainda vou mudar essa poda
function podainv(no::node)
  ###retorna 1 caso positivo (relaxação inviavel, realize a poda) e 0 caso a relaxação seja viavel e prossiga para outros testes
  if no.status == "Optimal"
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
  ### ver como definir -infinity, usei um numero mt pequeno já que nao posso comparar com o uper bound antigo (posso ter cortado)
  maior=-infinity
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



function branch (no::node)
  maior=-1
  for


function MILPSolver()

  S=

  n=S.L
  if podainv(n) == 1 || podaotim(n,lista) == 1 || podalimit(n,lista) == 1
    pop!(lista)
  end


#### quando atualizo op lb tenho que tirar da lista td mundo q tem um up menor que ele
