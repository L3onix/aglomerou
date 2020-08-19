#!/bin/bash

help()
{
	echo "Forma de uso:"
	echo -e "\t$0 COMANDO backend|database"
	echo -e "\t\t    build        - Criar container"
	echo -e "\t\t    run          - Iniciar container"
	echo -e "\t\t    rerun        - Remove o container em execução, baixa imagem atualizada e executa novamente"
	echo -e "\t\t    logs         - Mostrar logs do container executado"
	echo -e "\t\t    rm ou remove - Excluir container forçadamente (já inclui -f)"
	echo -e "\t\t    push         - Enviar imagem para hub.docker.com"
	echo -e "\t\t    pull         - Baixar imagem de hub.docker.com"
	echo ""
	echo -e "\t$0 COMANDO database"
	echo -e "\t\t    connect      - Conectar ao servidor Postgres no container (requer o psql na máquina host)"
	echo -e "\t$0 rerun all       - Remove os containers em execução, baixa imagem atualizada e executa novamente"
	echo ""

	exit -1
}

if [[ $# -lt 2 ]]; then
	help
fi

env_vars()
{
	# As variáveis do ambiente de produção são usadas
	# apenas quando for rodar o container.
	# Assim, nenhuma informação possivelmente sensível
	# é armazenada dentro do imagem públic em hub.docker.com
	if [[ ! -f .env ]]; then
		echo "Arquivo .env não foi localizado. Copie a partir de backend/.env" >&2
		exit -1
	fi

	source .env
}

# Re-executa um container, baixando a imagem do Docker Hub
# $0 nome do script
# $1 backend|database
rerun()
{
	echo "# Removendo container $2"
	eval "$1 rm $2"; echo ""
	echo "# Baixando imagem $1 do Docker Hub"
	eval "$1 pull $2"; echo ""
	echo "# Iniciando novo container $2"
	eval "$1 run $2"
}

if [[ $2 == "backend" ]]; then
	env_vars
	IMAGE_NAME="manoelcampos/aglomerou:backend"
	CONTAINER_NAME="aglomerou-backend"
	if [[ $1 == "build" ]]; then
		# Cria uma imagem Docker para o backend com Node.js,
		# definindo o contexto (pasta onde onde os arquivos serão copiados)
		# como a pasta atual.
		docker build -f ../backend/Dockerfile -t $IMAGE_NAME ../backend || exit -1
		echo ""
		echo "Use $0 run $2 pra iniciar container criado"
	elif [[ $1 == "run" ]]; then
		# Executar o container em background (-d)
		docker run --name $CONTAINER_NAME --restart unless-stopped -d -p $PORT:8080 --env-file .env $IMAGE_NAME || exit -1
		echo ""
		echo "Use $0 logs $2 pra exibir os logs do container executado"
	elif [[ $1 == "rerun" ]]; then
		rerun $0 $2
	fi
elif [[ $2 == "database" || $2 == "db" ]]; then
	env_vars
	IMAGE_NAME="manoelcampos/aglomerou:database"
	CONTAINER_NAME="aglomerou-postgres"

	if [[ $1 == "build" ]]; then
		docker build -f ../database/Dockerfile -t $IMAGE_NAME ../database || exit -1
		echo ""
		echo "Use $0 run $2 pra iniciar container criado"
	elif [[ $1 == "run" ]]; then	
		# Executar o container em background (-d)
		docker run -d --name $CONTAINER_NAME --restart unless-stopped \
				-e POSTGRES_USER -e POSTGRES_PASSWORD \
				-p $POSTGRES_PORT:5432 $IMAGE_NAME || exit -1
		echo ""
		echo "Use $0 logs $2 pra exibir os logs do container executado"
		echo "Use $0 connect $2 pra conectar ao servidor Postgres no container"
	elif [[ $1 == "rerun" ]]; then
		rerun $0 $2
	elif [[ $1 == "connect" ]]; then
		#https://www.postgresql.org/docs/9.1/libpq-envars.html
		PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_DATABASE 
	fi
elif [[ $2 == "all" ]]; then	
	if [[ $1 == "rerun" ]]; then
		rerun $0 "backend"
		echo "----------------------------------------------------------------------------"
		rerun $0 "database"
	fi
else
	help
fi

if [[ $1 == "logs" ]]; then	
	docker container logs $CONTAINER_NAME
elif [[ $1 == "rm" || $1 == "remove" ]]; then
	docker rm -f $CONTAINER_NAME
elif [[ $1 == "push" ]]; then
	docker push $IMAGE_NAME
elif [[ $1 == "pull" ]]; then
	docker pull $IMAGE_NAME
fi

	