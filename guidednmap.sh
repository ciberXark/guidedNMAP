#!/bin/bash

# Función Ctrl+C
function ctrl_c(){
    echo -e "\n${COLOR_AMARILLO_NEGRITA}Saliendo...${COLOR_RESET}"
    exit 1
}

# Definir colores
COLOR_ROJO='\033[0;31m'
COLOR_VERDE='\033[0;32m'
COLOR_AMARILLO='\033[0;33m'
COLOR_AZUL='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CIAN='\033[0;36m'

# Colores en negrita
COLOR_ROJO_NEGRITA='\033[1;31m'
COLOR_VERDE_NEGRITA='\033[1;32m'
COLOR_AMARILLO_NEGRITA='\033[1;33m'
COLOR_AZUL_NEGRITA='\033[1;34m'
COLOR_MAGENTA_NEGRITA='\033[1;35m'
COLOR_CIAN_NEGRITA='\033[1;36m'
COLOR_BLANCO_NEGRITA='\033[1;37m'

# Resetear color
COLOR_RESET='\033[0m'

# Función para guardar el resultado en un archivo
guardar_resultado() {
    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea guardar el resultado en un documento .txt? (y/n)${COLOR_RESET}\n"
        read -p "Seleccione una opción: " guardar_opcion

        guardar_opcion=$(echo "$guardar_opcion" | tr '[:upper:]' '[:lower:]')

        if [[ "$guardar_opcion" == "y" || "$guardar_opcion" == "yes" || "$guardar_opcion" == "si" || "$guardar_opcion" == "s" ]]; then
            read -p "Escriba el nombre que desea que tenga el archivo (sin .txt): " nombre_archivo
            nmap_command="$nmap_command -oN ${nombre_archivo}.txt"
            break
        elif [[ "$guardar_opcion" == "n" || "$guardar_opcion" == "no" || "$guardar_opcion" == "n" ]]; then
            break
        else
            echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n"
        fi
    done

    echo -e "\n\n${COLOR_CIAN_NEGRITA}Ejecutando: $nmap_command${COLOR_RESET}\n\n"
    eval $nmap_command
    exit 0
}
trap ctrl_c INT

# Función para actualizar nmap
actualizar_nmap() {
    echo -e "${COLOR_AZUL_NEGRITA}Actualizando NMAP...${COLOR_RESET}"

    # Verificar si el usuario es root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${COLOR_ROJO_NEGRITA}[!] Esta opción requiere permisos de superusuario. Por favor, ejecute el script como root.${COLOR_RESET}\n"
        exit 1
    fi

    # Actualizar nmap en diferentes distribuciones
    if command -v apt-get > /dev/null; then
        apt-get update && apt-get install --only-upgrade nmap
    elif command -v yum > /dev/null; then
        yum update nmap
    elif command -v dnf > /dev/null; then
        dnf upgrade nmap
    elif command -v pacman > /dev/null; then
        pacman -Syu nmap
    else
        echo -e "${COLOR_ROJO_NEGRITA}[!] No se puede determinar el gestor de paquetes. Actualización fallida.${COLOR_RESET}\n"
        exit 1
    fi

    echo -e "${COLOR_VERDE_NEGRITA}NMAP ha sido actualizado correctamente.${COLOR_RESET}"
}
trap ctrl_c INT

# Función para validar puertos
validar_puertos() {
    local puertos="$1"
    # Expresión regular para validar puertos (números entre 1 y 65535)
    if [[ $puertos =~ ^([0-9]+,)*[0-9]+$ ]]; then
        IFS=',' read -r -a lista_puertos <<< "$puertos"
        for puerto in "${lista_puertos[@]}"; do
            if (( puerto < 1 || puerto > 65535 )); then
                echo -e "${COLOR_ROJO_NEGRITA}[!] Error: Uno o más puertos están fuera del rango válido (1-65535).${COLOR_RESET}\n"
                return 1
            fi
        done
        return 0
    else
        echo -e "${COLOR_ROJO_NEGRITA}[!] Error: El formato de puertos no es válido.${COLOR_RESET}\n"
        return 1
    fi
}
trap ctrl_c INT

# Función para validar la estructura de una dirección MAC
validar_mac() {
    local mac="$1"
    # Expresión regular para validar dirección MAC (formato XX:XX:XX:XX:XX:XX)
    if [[ $mac =~ ^([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}$ ]]; then
        return 0
    else
        echo -e "${COLOR_ROJO_NEGRITA}[!] Error: La dirección MAC no tiene un formato válido. Debe ser XX:XX:XX:XX:XX:XX.${COLOR_RESET}\n"
        return 1
    fi
}
trap ctrl_c INT

# Función para validar la estructura de una dirección IP
validar_ip() {
    local ip="$1"
    # Expresión regular para validar dirección IP (formato XXX.XXX.XXX.XXX)
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octetos <<< "$ip"
        for octeto in "${octetos[@]}"; do
            if (( octeto < 0 || octeto > 255 )); then
                echo -e "${COLOR_ROJO_NEGRITA}[!] Error: Uno o más octetos están fuera del rango válido (0-255).${COLOR_RESET}\n"
                return 1
            fi
        done
        return 0
    else
        echo -e "${COLOR_ROJO_NEGRITA}[!] Error: La dirección IP no tiene un formato válido.${COLOR_RESET}\n"
        return 1
    fi
}
trap ctrl_c INT

# Función para el menú de escaneo de un rango IP
escanear_rango_ip() {
    while true; do
        echo -e "\n${COLOR_AZUL}Establezca la dirección IP cuyo rango desea escanear (por ejemplo, 192.168.1.0):${COLOR_RESET} "
        read -p "Dirección IP: " ip_rango

        # Validar la dirección IP
        if validar_ip "$ip_rango"; then
            # Verificar que la IP termina en .0
            if [[ $ip_rango =~ \.0$ ]]; then
                break
            else
                echo -e "${COLOR_ROJO_NEGRITA}[!] Error: La dirección IP debe terminar en .0 para escanear un rango.${COLOR_RESET}\n"
            fi
        fi
    done

    while true; do
        echo -e "${COLOR_AZUL}Establezca la máscara de subred (por ejemplo, /24):${COLOR_RESET} "
        read -p "Máscara de subred: " mascara_subred

        # Expresión regular para validar el formato de la máscara de subred
        if [[ $mascara_subred =~ ^/[0-9]+$ ]]; then
            prefix_length=${mascara_subred#/}

            # Validar que el valor del prefijo esté en el rango 0-32
            if (( prefix_length >= 0 && prefix_length <= 32 )); then
                break
            else
                echo -e "${COLOR_ROJO_NEGRITA}[!] Error: La máscara de subred debe estar en el rango /0 a /32.${COLOR_RESET}\n"
            fi
        else
            echo -e "${COLOR_ROJO_NEGRITA}[!] Error: La máscara de subred debe seguir el formato '/x', donde x es un número.${COLOR_RESET}\n"
        fi
    done

    nmap_command="nmap ${ip_rango}${mascara_subred}"
    guardar_resultado
}
trap ctrl_c INT

# Función para el menú de escaneo de una dirección IP concreta
escanear_ip_concreta() {
    while true; do
        echo -e "\n${COLOR_AZUL}Establezca la dirección IP a escanear:${COLOR_RESET} "
        read -p "Dirección IP: " ip_concreta

        # Validar la dirección IP
        if validar_ip "$ip_concreta"; then
            break
        fi
    done

    nmap_command="nmap $ip_concreta"

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Qué tipo de puertos desea escanear?${COLOR_RESET}"
        echo -e "${COLOR_VERDE}1) Puertos TCP${COLOR_RESET}"
        echo -e "${COLOR_VERDE}2) Puertos UDP${COLOR_RESET}"
        echo -e "${COLOR_VERDE}3) Escaneo combinado TCP y UDP${COLOR_RESET}"
        echo -e "${COLOR_VERDE}4) Volver al menú principal${COLOR_RESET}\n"
        read -p "Seleccione una opción: " tipo_puertos

        case $tipo_puertos in
            1) nmap_command="$nmap_command -sT"; break ;;
            2) nmap_command="$nmap_command -sU"; break ;;
            3) nmap_command="$nmap_command -sS -sU"; break ;;
            4) return ;;
            *) echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n" ;;
        esac
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Qué puertos desea escanear?${COLOR_RESET}"
        echo -e "${COLOR_VERDE}1) Todos los puertos${COLOR_RESET}"
        echo -e "${COLOR_VERDE}2) Sólo los puertos más comunes${COLOR_RESET}"
        echo -e "${COLOR_VERDE}3) Sólo los puertos abiertos${COLOR_RESET}"
        echo -e "${COLOR_VERDE}4) Especificar puertos manualmente${COLOR_RESET}"
        echo -e "${COLOR_VERDE}5) Volver al menú principal${COLOR_RESET}\n"
        read -p "Seleccione una opción: " opcion_puertos

        case $opcion_puertos in
            1) nmap_command="$nmap_command -p-"; break ;;
            2) nmap_command="$nmap_command --top-ports 100"; break ;;
            3) nmap_command="$nmap_command --open"; break ;;
            4) 
                read -p "Introduzca los puertos a escanear (de ser varios, deben ir separados por comas y sin espacio, por ejemplo, 22,80,443): " puertos_especificos
                if validar_puertos "$puertos_especificos"; then
                    nmap_command="$nmap_command -p $puertos_especificos"
                    break
                fi
                ;;
            5) return ;;
            *) echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n" ;;
        esac
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea realizar un escaneo de Sistema Operativo? (y/n)${COLOR_RESET}\n"
        read -p "Seleccione una opción: " os_opcion

        os_opcion=$(echo "$os_opcion" | tr '[:upper:]' '[:lower:]')

        if [[ "$os_opcion" == "y" || "$os_opcion" == "yes" || "$os_opcion" == "si" || "$os_opcion" == "s" ]]; then
            nmap_command="$nmap_command -O"
            break
        elif [[ "$os_opcion" == "n" || "$os_opcion" == "no" || "$os_opcion" == "n" ]]; then
            break
        else
            echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n"
        fi
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea ajustar la velocidad del escaneo?${COLOR_RESET}"
        echo -e "${COLOR_VERDE}1) Lento (menos detectable)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}2) Normal (valor por defecto)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}3) Rápido (más detectable)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}4) Volver al menú principal${COLOR_RESET}\n"
        read -p "Seleccione una opción: " velocidad_opcion

        case $velocidad_opcion in
            1) nmap_command="$nmap_command -T1"; break ;;
            2) nmap_command="$nmap_command -T3"; break ;;
            3) nmap_command="$nmap_command -T5"; break ;;
            4) return ;;
            *) echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n" ;;
        esac
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea realizar resolución de DNS? Si no se lleva a cabo, el escaneo será más rápido. (y/n)${COLOR_RESET}\n"
        read -p "Seleccione una opción: " dns_opcion

        dns_opcion=$(echo "$dns_opcion" | tr '[:upper:]' '[:lower:]')

        if [[ "$dns_opcion" == "y" || "$dns_opcion" == "yes" || "$dns_opcion" == "si" || "$dns_opcion" == "s" ]]; then
            break
        elif [[ "$dns_opcion" == "n" || "$dns_opcion" == "no" || "$dns_opcion" == "n" ]]; then
            nmap_command="$nmap_command -n"
            break
        else
            echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n"
        fi
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea llevar a cabo la detección de host (ping)? Si no se realiza, el escaneo será más rápido. (y/n)${COLOR_RESET}\n"
        read -p "Seleccione una opción: " dns_opcion

        dns_opcion=$(echo "$dns_opcion" | tr '[:upper:]' '[:lower:]')

        if [[ "$dns_opcion" == "y" || "$dns_opcion" == "yes" || "$dns_opcion" == "si" || "$dns_opcion" == "s" ]]; then
            break
        elif [[ "$dns_opcion" == "n" || "$dns_opcion" == "no" || "$dns_opcion" == "n" ]]; then
            nmap_command="$nmap_command -Pn"
            break
        else
            echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n"
        fi
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Qué técnicas de evasión de firewall desea aplicar?${COLOR_RESET}"
        echo -e "${COLOR_VERDE}1) Fragmentar paquetes (divide los paquetes en fragmentos de 8 bytes después de la cabecera IP)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}2) Usar TTL bajo (fija el tiempo de vida de las sondas enviadas)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}3) Polimorfismo (usado para enmascarar la propia IP durante el escaneo y dificultar la traza del origen)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}4) Ninguna${COLOR_RESET}\n"
        read -p "Seleccione una opción: " evasion_opcion

        case $evasion_opcion in
            1) nmap_command="$nmap_command -f"; break ;;
            2) nmap_command="$nmap_command --ttl 1"; break ;;
            3) nmap_command="$nmap_command -D RND:10"; break ;;
            4) break ;;
            *) echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n" ;;
        esac
    done

    while true; do
        echo -e "\n${COLOR_AMARILLO}¿Desea utilizar técnicas de spoofing?${COLOR_RESET}"
        echo -e "${COLOR_VERDE}1) Spoofing de dirección MAC (envía tramas Ethernet con la dirección origen especificada)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}2) Spoofing de dirección IP (permite especificar qué dirección IP usar como origen para los paquetes en un escaneo)${COLOR_RESET}"
        echo -e "${COLOR_VERDE}3) No${COLOR_RESET}\n"
        read -p "Seleccione una opción: " spoofing_opcion

        case $spoofing_opcion in
            1)
                read -p "Introduzca la dirección MAC a suplantar: " mac_spoof
                if validar_mac "$mac_spoof"; then
                    nmap_command="$nmap_command --spoof-mac $mac_spoof"
                    break
                fi
                ;;
            2)
                read -p "Introduzca la dirección IP a suplantar: " ip_spoof
                if validar_ip "$ip_spoof"; then
                    nmap_command="$nmap_command -S $ip_spoof"
                    break
                fi
                ;;
            3) break ;;
            *) echo -e "${COLOR_ROJO_NEGRITA}[!] Opción inválida.${COLOR_RESET}\n" ;;
        esac
    done

    guardar_resultado
}
trap ctrl_c INT

# Función para el menú principal
while true; do
    echo -e "${COLOR_AZUL_NEGRITA}                                                                                                          
                                              @@@@@@@@@@                                                                                    
                                           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                                                   
                                        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                                         
                                     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                                 
                                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                          
                            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                    
                                                                  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                               
                                                       ${COLOR_ROJO_NEGRITA}@@@${COLOR_RESET}                    ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                          
                                             @@@@@${COLOR_RESET}      ${COLOR_ROJO_NEGRITA}@@@@${COLOR_RESET}                          ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                     
                                      @@@@@@@@${COLOR_RESET}            ${COLOR_ROJO_NEGRITA}@@@@   @@@@@@@@@${COLOR_RESET}                  ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                 
                                 @@@@@@@@@@${COLOR_RESET}                  ${COLOR_ROJO_NEGRITA}@@@@@@@   @@@@@@@@${COLOR_RESET}                   ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@             
                            @@@@@@@@@@@@${COLOR_RESET}                                      ${COLOR_ROJO_NEGRITA}@@@@       @@@${COLOR_RESET}           ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@         
                       @@@@@@@@@@@@@@${COLOR_RESET}                   ${COLOR_ROJO_NEGRITA}@@@@      @@@@@@@@@           @@@@${COLOR_RESET}                 ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@@     
                   @@@@@@@@@@@@@@@@${COLOR_RESET}                   ${COLOR_ROJO_NEGRITA}@@@@      @@        @@       @@@@@${COLOR_RESET}                       ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@@@@  
               @@@@@@@@@@@@@@@@@@${COLOR_RESET}                    ${COLOR_ROJO_NEGRITA}@@@@   @@       @@       @@   @@@${COLOR_RESET}                           ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@@@   
            @@@@@@@@@@@@@@@@@@@${COLOR_RESET}                      ${COLOR_ROJO_NEGRITA}@@@   @@     @@@@@@@@     @@   @@@${COLOR_RESET}                         ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@@@      
         @@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                        ${COLOR_ROJO_NEGRITA}@@@   @@    @@@@@@@@@@    @@   @@@${COLOR_RESET}                        ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@@         
      @@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                         ${COLOR_ROJO_NEGRITA}@@@   @@     @@@@@@@@     @@   @@@${COLOR_RESET}                      ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@@@            
   @@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                          ${COLOR_ROJO_NEGRITA}@@@   @@       @@      @@    @@@@${COLOR_RESET}                    ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@@@                
    @@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                     ${COLOR_ROJO_NEGRITA}@@@@@       @@       @@       @@@@${COLOR_RESET}                   ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@@                    
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}               ${COLOR_ROJO_NEGRITA}@@@@            @@@@@@@@      @@@@${COLOR_RESET}                  ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@@@                        
           @@@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}        ${COLOR_ROJO_NEGRITA}@@@        @@@@${COLOR_RESET}                                     ${COLOR_AZUL_NEGRITA}@@@@@@@@@@@@                            
               @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                 ${COLOR_ROJO_NEGRITA}@@@@@@@   @@@@@@@${COLOR_RESET}                  ${COLOR_AZUL_NEGRITA}@@@@@@@@@                                  
                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                ${COLOR_ROJO_NEGRITA}@@@@@@@@@   @@@@${COLOR_RESET}           ${COLOR_AZUL_NEGRITA}@@@@@@@@                                       
                       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                       ${COLOR_ROJO_NEGRITA}@@@@${COLOR_RESET}     ${COLOR_AZUL_NEGRITA}@@@@@                                              
                            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${COLOR_RESET}                ${COLOR_ROJO_NEGRITA}@@@${COLOR_RESET}                                                       
${COLOR_AZUL_NEGRITA}                                @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                                             
                                       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                             
                                             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                 
                                                     @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                     
                                                             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@                                        
                                                                        @@@@@@@@@@@@@@@@@@@@@@@@@                                           
                                                                                    @@@@@@@@@@${COLOR_RESET}                                
                                                                                                                                            
${COLOR_VERDE_NEGRITA}                                                                                                                      
    @@@@@@       @@  @@       @@@       @@@@@@       @@@@@@       @@@@@@                @@@  @@       @@     @@        @@@@        @@@@@@@  
    @@           @@  @@       @@@       @@   @@      @@@          @@   @@               @@@@ @@       @@@   @@@       @@@@@@       @@@  @@  
    @@ @@@       @@  @@       @@@       @@   @@      @@@@@        @@   @@               @@ @@@@       @@@@ @@@@       @@  @@       @@@@@@@  
    @@  @@       @@  @@       @@@       @@   @@      @@@          @@   @@               @@  @@@       @@ @@@ @@       @@@@@@       @@@      
    @@@@@@       @@@@@@       @@@       @@@@@@       @@@@@@       @@@@@@                @@   @@       @@  @  @@       @@  @@       @@@      
${COLOR_RESET}                                                                                                                                   v.0.15.3

                                                     Desarrollado por: ${COLOR_VERDE_NEGRITA}Sergio${COLOR_RESET} ${COLOR_ROJO_NEGRITA}'Xark'${COLOR_RESET} ${COLOR_VERDE_NEGRITA}Gracia${COLOR_RESET}
                                                                       ${COLOR_AMARILLO_NEGRITA}https://ciberxark.es${COLOR_RESET}
                                                                                                                                                                                                                                                                                        "
    echo -e "${COLOR_CIAN_NEGRITA}¡Bienvenid@ a Guided NMAP!${COLOR_RESET}\n"
    echo -e "${COLOR_AZUL_NEGRITA}¿Qué desea hacer?${COLOR_RESET}"
    echo -e "${COLOR_VERDE_NEGRITA}1) Escanear una red${COLOR_RESET}"
    echo -e "${COLOR_VERDE_NEGRITA}2) Escanear una dirección IP concreta${COLOR_RESET}"
    echo -e "${COLOR_VERDE_NEGRITA}3) Actualizar NMAP${COLOR_RESET}"
    echo -e "${COLOR_ROJO_NEGRITA}4) Salir${COLOR_RESET}\n"
    read -p "Seleccione una opción: " menu_opcion

    case $menu_opcion in
        1) escanear_rango_ip ;;
        2) escanear_ip_concreta ;;
        3) actualizar_nmap ;;
        4) echo -e "${COLOR_AMARILLO_NEGRITA}Saliendo...${COLOR_RESET}"; exit 0 ;;
        *) echo -e "${COLOR_ROJO}Opción inválida.${COLOR_RESET}" ;;
    esac
done
trap ctrl_c INT
