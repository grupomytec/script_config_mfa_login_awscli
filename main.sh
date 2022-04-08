#!/bin/bash
function check_var_isNull () {
    VAR=$1
    if [ -z $VAR ];
    then
        echo "True"
    else
        echo "False"
    fi
}
function check_file_exists () {
    FILE=$1
    if [ -e $FILE ];
    then
        echo "True"
    else
        echo "False"
    fi
}
function check_profile_exists () {
    STRING=$1
    FILE=$2
    VALUES=$(grep -i "${STRING}" "${FILE}")
    ARRAY=( ${VALUES} )
    for VAR in "${ARRAY[@]}";
    do
        if [ "${VAR}" == "${STRING}]" ];
        then
            echo "True"
        fi
    done
}
function check_aws_files () {
    if [[ `uname` == "Linux" ]];
    then
        FILE_CONFIG="/home/${USER}/.aws/config"
        FILE_CREDENTIALS="/home/${USER}/.aws/credentials"
    fi
    if [[ `uname` != "Linux" ]];
    then
        FILE_CONFIG="/Users/${USER}/.aws/config"
        FILE_CREDENTIALS="/Users/${USER}/.aws/credentials"        
    fi
    return
}
function install_jq () {
    CLEAR=$(which clear)
    ${CLEAR}
    CURL=$(which curl)
    JQ=$(which jq)
    JQ_IS_NULL=$(check_var_isNull ${JQ})
    if [ "${JQ_IS_NULL}" == "True" ];
    then
        echo "Instalando 'jq', essencial para nossa configuração, aguarde!"
        if [[ `uname` == "Linux" ]];
        then
            INSTALL_JQ=$(sudo ${CURL} -s https://webinstall.dev/jq | bash)
            export PATH="/home/${USER}/.local/bin:$PATH"
        fi
        if [[ `uname` != "Linux" ]];
        then
            INSTALL_BREW=$(sudo ${CURL} -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | bash)
            BREW=$(which brew)
            BREW_IS_NULL=$(check_var_isNull ${JQ})
            if [ "${BREW_IS_NULL}" == "False" ];
            then
                INSTALL_JQ=$(brew install jq)
            else
                echo "Erro ao instalar JQ, retornando ao menu anterior"
            fi
        fi
        sleep 10
        CLEAR=$(which clear)
        ${CLEAR}
        return
    else
        return
    fi
}
function install_cli_ubuntu_debian () {
    CURL=$(which curl)
    ${CURL} "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    UNZIP=$(which unzip)
    ${UNZIP} awscliv2.zip
    INSTALL=$(sudo ./aws/install)
    return
}
function install_cli_macos () {
    CURL=$(which curl)
    ${CURL} "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    INSTALL=$(sudo installer -pkg AWSCLIV2.pkg -target /)
    return
}
function install_cli () {
    CLEAR=$(which clear)
    ${CLEAR}
    PS3='Entre com a opção correspondente ao seu Sistema Operacional: '
    options=("Linux Ubuntu/Debian" "MacOS" "Retornar ao menu anterior" "Encerrar")
    select opt in "${options[@]}"
    do
        case $opt in
            "Linux Ubuntu/Debian")
                install_cli_ubuntu_debian
                ${CLEAR}
                AWS_CLI=$(which aws)
                AWS_CLI_IS_NULL=$(check_var_isNull ${AWS_CLI})
                if [ "${AWS_CLI_IS_NULL}" == "False" ];
                then
                    echo "AWS CLI instalado com sucesso, retornando ao menu anterior"
                else
                    echo "Erro ao instalar AWS CLI, retornando ao menu anterior"
                fi
                sleep 5
                main_menu
                ;;
            "MacOS")
                install_cli_macos
                ${CLEAR}
                AWS_CLI=$(which aws)
                AWS_CLI_IS_NULL=$(check_var_isNull ${AWS_CLI})
                if [ "${AWS_CLI_IS_NULL}" == "False" ];
                then
                    echo "AWS CLI instalado com sucesso, retornando ao menu anterior"
                else
                    echo "Erro ao instalar AWS CLI, retornando ao menu anterior"
                fi
                sleep 5
                main_menu
                ;;
            "Retornar ao menu anterior")
                main_menu
                ;;
            "Encerrar")
                exit
                ;;
            *) echo "Opção inválida $REPLY";;
        esac
    done
}
function configure_mfa () {
    CLEAR=$(which clear)
    ${CLEAR}
    AWS_CLI=$(which aws)
    AWS_CLI_IS_NULL=$(check_var_isNull ${AWS_CLI})
    if [ "${AWS_CLI_IS_NULL}" == "False" ];
    then
        check_aws_files
        if [[ -e ${FILE_CONFIG} ]] && [[ -e $FILE_CREDENTIALS ]];
        then
            echo "Insira um nome para o perfil:"
            read PROFILE_NAME
            PROFILE_NAME_EXISTS=$(check_profile_exists ${PROFILE_NAME} ${FILE_CONFIG})
            PROFILE_NAME_IS_NULL=$(check_var_isNull ${PROFILE_NAME_EXISTS})
            if [ "${PROFILE_NAME_IS_NULL}" == "True" ];
            then
                ${AWS_CLI} configure --profile ${PROFILE_NAME}
                login_mfa ${PROFILE_NAME}
            else
                ${CLEAR}
                echo "Um perfil com este mesmo nome já está configurado"
                echo "No menu anterior selecione a opção '3' para fazer login"
                echo "Retornando ao menu principal em 10s"
                sleep 10
                main_menu
            fi
        else
            echo "Arquivos de configuração do AWS CLI não encontrados"
            echo "Tem certeza de que está instalado?"
            echo "Retornando ao menu principal em 10s"
            sleep 10
            main_menu
        fi
    else
        echo "Parece que o AWS CLI não está instalado"
        echo "Retornando ao menu principal em 10s"
        sleep 10
        main_menu
    fi
}
function login_mfa () {
    PROFILE_NAME=$1
    CLEAR=$(which clear)
    ${CLEAR}
    AWS_CLI=$(which aws)
    AWS_CLI_IS_NULL=$(check_var_isNull ${AWS_CLI})
    if [ "${AWS_CLI_IS_NULL}" == "False" ];
    then
        install_jq
        echo "Insira seu nome de usuário da AWS:"
        read AWS_USERNAME
        AWS_SERIAL_NUMBER=$(${AWS_CLI} iam list-mfa-devices --user-name ${AWS_USERNAME} --output json --profile ${PROFILE_NAME} | jq '.MFADevices[0] .SerialNumber' | sed 's/"//g')
        echo "Insira seu Código MFA:"
        read AWS_TOKEN_CODE
        AWS_TOKEN_CODE_RESPONSE=$(${AWS_CLI} sts get-session-token --serial-number ${AWS_SERIAL_NUMBER} --token-code ${AWS_TOKEN_CODE} --output json --profile ${PROFILE_NAME})
        AWS_ACCESS_KEY=$(echo ${AWS_TOKEN_CODE_RESPONSE} | jq '.Credentials .AccessKeyId' | sed 's/"//g')
        AWS_SECRET_KEY=$(echo ${AWS_TOKEN_CODE_RESPONSE} | jq '.Credentials .SecretAccessKey' | sed 's/"//g')
        AWS_SESSION_TOKEN=$(echo ${AWS_TOKEN_CODE_RESPONSE} | jq '.Credentials .SessionToken' | sed 's/"//g')
        SET_AWS_ACCESS_KEY=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa" aws_access_key_id ${AWS_ACCESS_KEY})
        SET_AWS_SECRET_KEY=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa" aws_secret_access_key ${AWS_SECRET_KEY})
        SET_AWS_SESSION_TOKEN=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa" aws_session_token ${AWS_SESSION_TOKEN})
        SET_REGION=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa" region 'us-east-1')
        SET_OUTPUT=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa" output 'json')
        change_role_aws ${PROFILE_NAME}
    else
        echo "Parece que o AWS CLI não está instalado"
        echo "Retornando ao menu principal em 10s"
        sleep 10
        main_menu
    fi
}
function change_role_aws (){
    PROFILE_NAME=$1
    CLEAR=$(which clear)
    ${CLEAR}
    echo "Deseja alterar a Role?"
    PS3='Entre com o número de sua escolha: '
        options=("Alterar role" "Não alterar role" "Encerrar")
    select opt in "${options[@]}"
    do
        case $opt in
            "Alterar role")
                GET_ACCOUNT_ID=$(${AWS_CLI} sts get-caller-identity --profile "${PROFILE_NAME}" --output json | jq '.Account' | sed 's/"//g')
                echo "Insira o nome da Role"
                read ROLE_NAME
                AWS_CLI=$(which aws)
                AWS_CLI_IS_NULL=$(check_var_isNull ${AWS_CLI})
                if [ "${AWS_CLI_IS_NULL}" == "False" ];
                then
                    SET_ROLE=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa-role" role_arn "arn:aws:iam::${GET_ACCOUNT_ID}:role/${ROLE_NAME}")
                    SET_SOURCE_PROFILE=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa-role" source_profile "${PROFILE_NAME}-mfa")
                    SET_REGION=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa-role" region 'us-east-1')
                    SET_OUTPUT=$(${AWS_CLI} configure set --profile "${PROFILE_NAME}-mfa-role" output 'json')
                    echo "No passo a seguir selecione o perfil '${PROFILE_NAME}-mfa-role'"
                    sleep 10
                    AWSP=$(which _awsp)
                    ${AWSP}
                    echo "Retornando ao menu principal em 10s"
                    sleep 10
                    main_menu
                else
                    echo "Parece que o AWS CLI não está instalado"
                    echo "Retornando ao menu principal em 10s"
                    sleep 10
                    main_menu
                fi
                ;;
            "Não alterar role")
                echo "No passo a seguir selecione o perfil '${PROFILE_NAME}-mfa-role'"
                AWSP=$(which _awsp)
                ${AWSP}
                echo "Retornando ao menu principal em 10s"
                main_menu
                ;;
            "Encerrar")
                exit
                ;;
            *) echo "Opção inválida";;
        esac
    done
}
function main_menu () {
    CLEAR=$(which clear)
    ${CLEAR}
    PS3='Entre com o número de sua escolha: '
    options=("Instalar AWS CLI" "Configurar AWS CLI MultiFactor Authentication" "Login AWS CLI MultiFactor" "Encerrar")
    select opt in "${options[@]}"
    do
        case $opt in
            "Instalar AWS CLI")
                install_cli
                ;;
            "Configurar AWS CLI MultiFactor Authentication")
                configure_mfa
                ;;
            "Login AWS CLI MultiFactor")
                check_aws_files
                if [[ -e ${FILE_CONFIG} ]] && [[ -e $FILE_CREDENTIALS ]];
                then
                    ${CLEAR}
                    echo "Insira o nome do perfil de uma conta previamente configurada:"
                    read PROFILE_NAME
                    check_aws_files
                    PROFILE_NAME_EXISTS=$(check_profile_exists ${PROFILE_NAME} ${FILE_CONFIG})
                    PROFILE_NAME_IS_NULL=$(check_var_isNull ${PROFILE_NAME_EXISTS})
                    if [ "${PROFILE_NAME_IS_NULL}" == "True" ];
                    then
                        ${CLEAR}
                        echo "Parece que este perfil não está configurado"
                        echo "No menu anterior selecione a opção '2' para realizar a configuração"
                        echo "Retornando ao menu principal em 10s"
                        sleep 10
                        main_menu
                    else
                        login_mfa ${PROFILE_NAME}
                    fi
                else
                    echo "Arquivos de configuração do AWS CLI não encontrados"
                    echo "Tem certeza de que está instalado?"
                    echo "Retornando ao menu principal em 10s"
                    sleep 10
                    main_menu
                fi
                ;;
            "Encerrar")
                exit
                ;;
            *) echo "Opção inválida";;
        esac
    done
}

main_menu