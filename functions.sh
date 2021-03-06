#!/bin/bash

# parametre $1 : nom de logiciel a verifier
f_check_soft() {
   which $1 > /dev/null
    if [ $? != 0 ] ; then
        print " $1	---> [ KO ]"
	print "$1 non detecte sur cette distribution vous pouvez"
	print "l'installer en faisant un apt-get install $1 "
	print " et/ou verifier manuellement la presence du paquet"
        exit 1
    else
        print " $1	---> [ OK ]"
    fi
sleep 0.5
}


# Test de validite IPv4 de l'adresse entree (expression reguliere)
# parametre $1 : adresse IP à vérifier
# code de sortie : 0 pour ok et 1 pour adresse ipv4 non valide
f_isIPv4() {
if [ $# = 1 ]
then
 printf $1 | grep -Eq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-4]|2[0-4][0-9]|[01]?[1-9][0-9]?)$'
 return $?
else
 return 2
fi
}


f_verification_access_ping() {
# vérifier si le serveur est joiniable 
# code de sortie : 0 pour ok et 1 pour adresse ipv4 non valide
    if PATCH_PING=$(which ping) ; then 
	echo -en  "\t\nvérification de l'accessibilité du serveur"
        ${PATCH_PING} -c1 $*
	# Si le resultat de la commande renvoi != 0 alors ça ping !
	echo $?
        if [ $? != 0 ] ; then return 2 echo toto;	else return 0;	fi
    else 
	return 2; 
    fi
}


f_generate_pair_authentication_keys() {
    echo -en  "\t\n Verification du paquet ssh-keygen \n"
    f_check_soft ssh-keygen

    echo -en  "\t\n Creation de la pair ssh sur le serveur local\n"
    if [ ! -f /root/.ssh/id_rsa.pub ]; then
   ssh-keygen -t rsa -f /$1/.ssh/id_rsa -N ""
    else 
    echo -en  "\t\n/$1/.ssh/id_rsa.pub exist"
   echo -en  "\t\n Utilisation de la pair de clé /$1/.ssh/id_rsa"
    fi
    echo -en  "\t\n------------> WARNING !!!! <------------ \n"
    echo -en  "\t\n------------> ETES VOUS PRET A RENTRER LE MOT DE PASSE de l'utilisateur $1 (presser entrer) <------------ \n"; read
    ssh-copy-id -i /$1/.ssh/id_rsa.pub $1@$2 -p $3
}

f_verification_connexion_ssh() {

    echo -en  "\t vérification de la connection ssh\n"

    cat > /tmp/expect-script.sh << EOF
#!/usr/bin/expect -f
set timeout 3
   
spawn ssh -p $3 $1@$2 ls -ld /etc
expect {
"yes/no" {send "yes\n"}
"etc" {exec echo $1@$2 >> /tmp/serveur-ok.txt}
}

expect {
"Password" {exec echo $1@$2 >> /tmp/serveur-nok.txt}
"etc" {exec echo $1@$2 >> /tmp/serveur-ok.txt}
}

EOF
    chmod 700 /tmp/expect-script.sh
    /tmp/expect-script.sh
    if [[ -f /tmp/serveur-ok.txt ]]; then export ETAT_SSH="OK"; else export ETAT_SSH="KO"; fi
    #clean function
    if [[ -f /tmp/serveur-*.txt ]]; then rm /tmp/serveur-*.txt; fi # supprime d'eventiels fichiers
    if [[ -f /tmp/expect-script.sh ]]; then rm /tmp/expect-script.sh; fi # supprime d'eventiels fichiers
}

println() {
    level=$1
    text=$2

    if [ "$level" == "error" ]; then
        echo -en "\033[0;36;31m$text\033[0;38;39m\n\r"
    elif [ "$level" == "ras" ]; then
        echo -en "\033[0;01;32m$text\033[0;38;39m\n\r"
    elif [ "$level" == "warn" ]; then
        echo -en "\033[0;36;33m$text\033[0;38;39m\n\r"
    else
        echo -en "\033[0;36;40m$text\033[0;38;39m\n\r"
    fi
}


f_ask_yn_question()
{
    QUESTION=$1

    while true;
    do 
        echo -en "${QUESTION} (y/n) "
        read REPLY
        if [ "${REPLY}" == "y" ];
        then
            return 0;
        fi
        if [ "${REPLY}" == "n" ];
        then
            return 1;
        fi
    echo "Don't tell you life, reply using 'y' or 'n'"'!'
    done
}


# function detection de distribution 
f_detectdistro () {
  if [[ -z $distro ]]; then
    distro="Unknown"
    if grep -i debian /etc/lsb-release >/dev/null 2>&1; then distro="debian"; fi
    if [ -f /etc/debian_version ]; then distro="debian"; fi
    if grep -i ubuntu /etc/lsb-release >/dev/null 2>&1; then distro="ubuntu"; fi
    if grep -i mint /etc/lsb-release >/dev/null 2>&1; then distro="linux Mint"; fi
    if [ -f /etc/arch-release ]; then distro="arch Linux"; fi
    if [ -f /etc/fedora-release ]; then distro="fedora"; fi
    if [ -f /etc/redhat-release ]; then distro="red Hat Linux"; fi
    if [ -f /etc/slackware-version ]; then distro="Slackware"; fi
    if [ -f /etc/SUSE-release ]; then distro="SUSE"; fi
    if [ -f /etc/mandrake-release ]; then distro="Mandrake"; fi
    if [ -f /etc/mandriva-release ]; then distro="Mandriva"; fi
    if [ -f /etc/crunchbang-lsb-release ]; then distro="Crunchbang"; fi
    if [ -f /etc/gentoo-release ]; then distro="Gentoo"; fi
    if [ -f /var/run/dmesg.boot ] && grep -i bsd /var/run/dmesg.boot; then distro="BSD"; fi
    if [ -f /usr/share/doc/tc/release.txt ]; then distro="Tiny Core"; fi
  fi
}


#LOG functions
f_LOG() {
    echo "`date`:$@" >> $LOGFILE
}
f_INFO() {
    echo "$@"
    f_LOG "INFO: $@"
}
f_WARNING() {
    echo "$@"
    f_LOG "WARNING: $@"
}

# Verifie la réponse saisie de l'utilisateur
# arg1 : saisie de l'utilisateur
# argn : reponses attendu de l'utilisateur
# f_checkanswer arg1 arg2 arg3 ... argn
f_checkanswer () {
#On stock tous les elements
tab=($*)
#on recupere le derniere element
f_element=${tab[0]}
tab=(${*:2})
for mot in ${tab[*]}
do
    if [ "$f_element" = $mot ];
    then
        return 1;
    fi
done
}

