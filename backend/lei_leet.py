import paho.mqtt.client as mqtt
import subprocess
import json
import firebase_admin
from firebase_admin import credentials, firestore
import threading
import time
from datetime import datetime

# Definição dos tópicos MQTT
TOPICO_LUZES_N = "shellyplus1pm-3c6105729b9c/events/rpc"
TOPICO_LUZES_I = "shellyplus1pm-3c6105729b9c/rpc"
TOPICO_ESTORES_N = "shellyplus2pm-b8d61a896c34/events/rpc"
TOPICO_ESTORES_I = "shellyplus2pm-b8d61a896c34/rpc"
TOPICO_PORTA = "porta/events/rpc"
TOPICO_AR_CONDICIONADO_N = "shelly1minig3-34b7da8e3c08/events/rpc"
TOPICO_AR_CONDICIONADO_I = "shelly1minig3-34b7da8e3c08/rpc"
TOPICO_APP = "app/fluxo"
TOPICO_TEMPERATURA = "zigbee2mqtt/0x00124b0029115211"
TOPICO_RESPOSTA_APP = "resposta/app/fluxo"
TOPICO_INICIO_PARAMETRIZACAO_APP = "inicio/parametrizacao/app/fluxo"
TOPICO_RESPOSTA_PARAMETRIZACAO_APP = "resposta/parametrizacao/app/fluxo"
TOPICO_ENVIO_PARAMETRIZACAO_APP = "envio/parametrizacao/app/fluxo"
TOPICO_ESTADO_APP = "estado/app/fluxo"

TEMPO_OPERACAO = 10
tempo_restante_subida = TEMPO_OPERACAO
tempo_restante_descida = 0
timer_operacao_subida = 0
timer_operacao_descida = 0
timer_s = None
timer_d = None
estado_i = {"Descer": "detached", "Subir": "follow"}
estado_a = "Desligado"
percentagem_abertura = tempo_restante_subida / TEMPO_OPERACAO

def ajuste_tempo():
    global tempo_restante_subida
    global tempo_restante_descida
    if tempo_restante_subida >= TEMPO_OPERACAO or tempo_restante_descida <= 0:
        tempo_restante_subida = TEMPO_OPERACAO
        tempo_restante_descida = 0
    elif tempo_restante_descida >= TEMPO_OPERACAO or tempo_restante_subida <= 0:
        tempo_restante_subida = 0
        tempo_restante_descida = TEMPO_OPERACAO

class BD_:
    def __init__(self):
        self.conectar_firestore()

    def conectar_firestore(self):
        try:
            if not firebase_admin._apps:  # Verifica se o Firebase já foi inicializado
                cred = credentials.Certificate("/home/bruno/lei_leet/credenciais.json")
                firebase_admin.initialize_app(cred)
            self.db = firestore.client()
            print("Conectado ao Firestore")
        except Exception as e:
            print(f"Erro ao conectar ao Firestore: {e}")

    def armazenar_dados(self, colecao, documento, dados):
        try:
            doc_ref = self.db.collection(colecao).document(documento)
            doc_ref.set(dados, merge=True)
        except Exception as e:
            print(f"Erro ao armazenar dados: {e}")

    def recuperar_dados(self, colecao, documento):
        try:
            doc_ref = self.db.collection(colecao).document(documento)
            dados = doc_ref.get().to_dict()
            return dados
        except Exception as e:
            print(f"Erro ao recuperar dados: {e}")
            return None

    def registrar_log(self, colecao, log_dados):
        try:
            log_ref = self.db.collection(colecao).document("historico")
            log_ref.update({
                "logs": firestore.ArrayUnion([log_dados])
            })
        except Exception as e:
            print(f"Erro ao registrar log: {e}")

    def verificar_login(self, dados_login):
        try:
            username = dados_login['username']
            password = dados_login['password']

            user_ref = self.db.collection("users").document("users")
            user_data = user_ref.get().to_dict()

            admin_ref = self.db.collection("users").document("admin")
            admin_data = admin_ref.get().to_dict()

            if user_data:
                for user_id, details in user_data.items():
                    if details['username'] == username:
                        if details['password'] == password:
                            self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "sucesso", "mensagem_log": "ok"})
                            return {'success': True, 'message': 'Login efetuado com sucesso'}
                        else:
                            self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "falha", "mensagem_log": "Senha incorreta"})
                            return {'success': False, 'message': 'Senha incorreta'}

            if admin_data:
                if admin_data['username'] == username:
                    if admin_data['password'] == password:
                        self.registrar_log("admin", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "sucesso", "mensagem_log": "ok"})
                        return {'success': True, 'message': 'Login efetuado com sucesso'}
                    else:
                        self.registrar_log("admin", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "falha", "mensagem_log": "Senha incorreta"})
                        return {'success': False, 'message': 'Senha incorreta'}

            self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "falha", "mensagem_log": "Usuário não encontrado"})
            return {'success': False, 'message': 'Usuário não encontrado'}
        except Exception as e:
            print(f"Erro ao verificar login: {e}")
            return {'success': False, 'message': 'Erro ao verificar login'}

    def armazenar_parametros(self, colecao, documento, parametros):
        try:
            estado = parametros.get("estado", "inativo")
            parametros["estado"] = estado
            
            doc_ref = self.db.collection(colecao).document(documento)
            doc_ref.update(parametros)
        except Exception as e:
            print(f"Erro ao armazenar parametros: {e}")

    def recuperar_parametros(self, colecao, documento):
        try:
            doc_ref = self.db.collection(colecao).document(documento)
            parametros = doc_ref.get().to_dict()
            return parametros
        except Exception as e:
            print(f"Erro ao recuperar parametros: {e}")
            return None

    def adicionar_user(self, username, password):
        try:
            users_collection = self.db.collection("users").document("users")
            user_data = users_collection.get().to_dict() or {}

            max_id = 0
            for user_id in user_data.keys():
                if user_id.startswith("user"):
                    try:
                        user_number = int(user_id[4:])
                        if (user_number > max_id):
                            max_id = user_number
                    except ValueError:
                        continue

            new_user_id = f"user{max_id + 1}"
            user_data[new_user_id] = {'username': username, 'password': password}
            users_collection.set(user_data)

            self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "sucesso", "mensagem_log": "Usuário criado com sucesso"})
            return {'success': True, 'message': 'Usuário criado com sucesso'}
        except Exception as e:
            print(f"Erro ao adicionar usuário: {e}")
            return {'success': False, 'message': 'Erro ao adicionar usuário'}

    def alterar_user(self, old_username, new_username, new_password):
        try:
            user_ref = self.db.collection("users").document("users")
            user_data = user_ref.get().to_dict()

            if not user_data or old_username not in user_data:
                self.registrar_log("users", {"user": old_username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "insucesso", "mensagem_log": "Usuário não encontrado"})
                return {'success': False, 'message': 'Usuário não encontrado'}

            if new_username in user_data and old_username != new_username:
                self.registrar_log("users", {"user": old_username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "insucesso", "mensagem_log": "Novo nome de usuário já existe"})
                return {'success': False, 'message': 'Novo nome de usuário já existe'}

            user_data[new_username] = user_data.pop(old_username)
            user_data[new_username]['username'] = new_username
            user_data[new_username]['password'] = new_password
            user_ref.set(user_data)

            self.registrar_log("users", {"user": new_username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "sucesso", "mensagem_log": "Usuário alterado com sucesso"})
            return {'success': True, 'message': 'Usuário alterado com sucesso'}
        except Exception as e:
            print(f"Erro ao alterar usuário: {e}")
            return {'success': False, 'message': 'Erro ao alterar usuário'}

    def remover_user(self, username):
        try:
            user_ref = self.db.collection("users").document("users")
            user_data = user_ref.get().to_dict()

            if not user_data or username not in user_data:
                self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "insucesso", "mensagem_log": "Usuário não encontrado"})
                return {'success': False, 'message': 'Usuário não encontrado'}

            user_data.pop(username)
            user_ref.set(user_data)

            self.registrar_log("users", {"user": username, "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"), "resultado": "sucesso", "mensagem_log": "Usuário removido com sucesso"})
            return {'success': True, 'message': 'Usuário removido com sucesso'}
        except Exception as e:
            print(f"Erro ao remover usuário: {e}")
            return {'success': False, 'message': 'Erro ao remover usuário'}

class Inf_t_:
    def __init__(self, mqtt_client):
        self.bd_ = BD_()
        self.mqtt_client = mqtt_client
        self.dispositivo_ = Dispositivo_(mqtt_client)
        self._estadoIluminacao = None
        self._estadoEstores = None
        self._estadoArCondicionado = None
        self.temperatura_pretendida = None

    def processar_mensagem(self, topic, mensagem):
        dados = json.loads(mensagem)
        if TOPICO_LUZES_N in topic:
            if "switch:0" in dados["params"] and "output" in dados["params"]["switch:0"]:
                estado = dados['params']['switch:0']['output']
                self._estadoIluminacao = "ligado" if estado else "desligado"
                self.notificar_estado("luzes", self._estadoIluminacao)
            if "input:0" in dados["params"]:
                self.tratar_luzes(dados, "interruptor")
        elif TOPICO_ESTORES_N in topic:
            if ("switch:0" in dados["params"] and "output" in dados["params"]["switch:0"]) or ("switch:1" in dados["params"] and "output" in dados["params"]["switch:1"]):
                estado_subir = dados['params']['switch:1']['output'] if "switch:1" in dados["params"] else None
                estado_descer = dados['params']['switch:0']['output'] if "switch:0" in dados["params"] else None
                if estado_subir is not None:
                    self._estadoEstores = "subindo" if estado_subir else self._estadoEstores
                if estado_descer is not None:
                    self._estadoEstores = "descendo" if estado_descer else self._estadoEstores
                if estado_subir is None and estado_descer is None:
                    self._estadoEstores = "parado"
                self.notificar_estado("estores", self._estadoEstores)
                print(f"[LOG] Estado dos estores atualizado: {self._estadoEstores}")
            if "input:0" in dados["params"] or "input:1" in dados["params"]:
                self.tratar_estores(dados, "interruptor")
        elif TOPICO_APP in topic:
            if dados.get("instrucao") == "login":
                self.tratar_user_pass(dados)
            elif dados.get("instrucao") == "Ordem":
                dispositivo = list(dados["parametros"].keys())[0]
                comando = dados["parametros"][dispositivo]
                if dispositivo == "luzes":
                    self.tratar_luzes({"estado": comando}, "app")
                    estado = "ligado" if comando == "ligar" else "desligado"
                    self.notificar_estado("luzes", estado)
                elif dispositivo == "estores":
                    self.tratar_estores({"estado": comando}, "app")
                    print(f"[LOG] Ordem recebida da app para estores: {comando}")
                elif dispositivo == "ar_condicionado":
                    self.tratar_ar_condicionado({"estado": comando}, "app")
                    estado = "ligado" if comando == "ligar" else "desligado"
                    self.notificar_estado("ar_condicionado", estado)
            elif dados.get("instrucao") == "Programar":
                self.tratar_parametros(dados)
            elif dados.get("instrucao") == "SolicitarParametrizacao":
                dispositivo = dados["dispositivo"]
                self.enviar_parametrizacao(dispositivo)
            elif dados.get("instrucao") == "AdicionarUser":
                username = dados["parametros"]["username"]
                password = dados["parametros"]["password"]
                self.adicionar_user(username, password)
            elif dados.get("instrucao") == "AlterarUser":
                old_username = dados["parametros"]["old_username"]
                new_username = dados["parametros"]["new_username"]
                new_password = dados["parametros"]["new_password"]
                self.alterar_user(old_username, new_username, new_password)
            elif dados.get("instrucao") == "RemoverUser":
                username = dados["parametros"]["username"]
                self.remover_user(username)
        elif TOPICO_TEMPERATURA in topic:
            self.tratar_temperatura(dados)
        elif TOPICO_INICIO_PARAMETRIZACAO_APP in topic:
            dispositivo = dados.get("dispositivo")
            if dispositivo:
                self.enviar_parametrizacao(dispositivo)
        elif TOPICO_ENVIO_PARAMETRIZACAO_APP in topic:
            self.tratar_parametros(dados)

    def notificar_estado(self, dispositivo, estado, informacoes_adicionais=None):
        mensagem = {
            "dispositivo": dispositivo,
            "estado": estado
        }
        if informacoes_adicionais:
            mensagem.update(informacoes_adicionais)
        print(f"[LOG] Notificando estado do {dispositivo}: {mensagem}")
        self.encaminhar_dados(TOPICO_ESTADO_APP, mensagem)

    def tratar_luzes(self, dados, origem):
        estado = dados['params']['input:0']['state'] if origem == "interruptor" else (dados['estado'] == "ligar")
        comando = {"luzes": "ligar" if estado else "desligar"}
        log_dados = {
            "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "instrucao": comando["luzes"],
            "origem": origem,
            "estado atual interruptor": estado,
            "Parametros Programação": self.bd_.recuperar_dados("luzes", "parametrizacao")
        }
        self.bd_.registrar_log("luzes", log_dados)
        self.bd_.armazenar_dados("luzes", "estado", {"luzes": "ligada" if estado else "desligada", "interruptor": "ligado" if estado else "desligado"})
        self.preparar_comando("luzes", comando)

    def tratar_estores(self, dados, origem):
        global timer_operacao_subida, timer_operacao_descida, tempo_restante_subida, tempo_restante_descida
        global timer_s, timer_d

        if origem == "interruptor":
            if 'input:0' in dados['params']:
                estado = dados['params']['input:0']['state']
                comando = {"estores": "descer" if estado else "parar"}
            elif 'input:1' in dados['params']:
                estado = dados['params']['input:1']['state']
                comando = {"estores": "subir" if estado else "parar"}
        else:
            estado = dados['estado']
            if estado == "subir":
                comando = {"estores": "subir"}
            elif estado == "descer":
                comando = {"estores": "descer"}
            else:
                comando = {"estores": "parar"}

        print(f"[LOG] Comando recebido para estores: {comando}")

        # Atualizar variáveis globais
        self.bd_.armazenar_dados("estores", "estado", {"funcionamento": "a descer" if comando["estores"] == "descer" else "a subir" if comando["estores"] == "subir" else "desligado"})

        # Preparar comando e publicar no tópico de resposta
        log_dados = {
            "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "instrucao": comando["estores"],
            "origem": origem,
            "estado atual interruptor": estado,
            "tempo_restante_subida": tempo_restante_subida,
            "tempo_restante_descida": tempo_restante_descida,
            "parametros Programação": self.bd_.recuperar_dados("estores", "parametrizacao")
        }
        self.bd_.registrar_log("estores", log_dados)
        self.preparar_comando("estores", comando)
        
    def verificar_temperatura_pretendida(self, temperatura_atual):
        if self.temperatura_pretendida is not None and self._estadoArCondicionado == "ligado":
            if temperatura_atual <= self.temperatura_pretendida - 0.2:
                self.tratar_ar_condicionado({"estado": "desligar"}, "sistema")
                self.notificar_estado("ar_condicionado", "desligado")
                self.bd_.armazenar_dados("ar_condicionado", "estado", {"ar_condicionado": "desligado", "temperatura_pretendida": "inativo"})
                self.temperatura_pretendida = None


    def tratar_temperatura(self, dados):
        temperatura = dados.get('temperature')
        if temperatura is not None:
            log_dados = {
                "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "temperature": temperatura,
                "humidity": dados.get('humidity'),
                "battery": dados.get('battery'),
                "linkquality": dados.get('linkquality'),
                "voltage": dados.get('voltage')
            }
            self.bd_.registrar_log("temperatura", log_dados)

            sensor_data = {
                "leitura_atual": temperatura,
                "estado": "ativo"
            }
            self.bd_.armazenar_dados("temperatura", "sensor", sensor_data)

            mensagem = {
                "informacao": "temperatura",
                "valor monotorizado": temperatura
            }
            self.encaminhar_dados(TOPICO_RESPOSTA_APP, mensagem)

            # Verificar se a temperatura pretendida foi atingida
            if self._estadoArCondicionado == "ligado" and self.temperatura_pretendida is not None:
                if temperatura <= self.temperatura_pretendida - 0.2:  # Verifique a temperatura pretendida corretamente
                    self.tratar_ar_condicionado({"estado": "desligar"}, "app")
                    self.notificar_estado("ar_condicionado", "desligado")
        else:
            print("Erro: Dados de temperatura não encontrados")


    def verificar_temperatura(self):
        dados_sensor = self.bd_.recuperar_dados("temperatura", "sensor")
        if dados_sensor:
            temperatura_atual = dados_sensor.get("leitura_atual")
            mensagem = {
                "informacao": "temperatura",
                "valor monotorizado": temperatura_atual
            }
            self.encaminhar_dados(TOPICO_RESPOSTA_APP, mensagem)
        else:
            print("Erro: Dados de temperatura não encontrados na base de dados")

    def tratar_user_pass(self, dados):
        username = dados.get('username')
        password = dados.get('password')
        if username and password:
            resultado = self.bd_.verificar_login({'username': username, 'password': password})
            print(f'Publicando resultado do login: {resultado}')
            self.encaminhar_dados(f"resposta/{TOPICO_APP}", resultado)

    def tratar_parametros(self, dados):
        dispositivo = dados.get('parametros', {}).get('dispositivo')
        parametros = dados.get('parametros', {}).get('parametros', {})

        if dispositivo:
            self.parametrizar_dispositivo(dispositivo, parametros)

    def parametrizar_dispositivo(self, dispositivo, parametros):
        estado = parametros.get("estado", "inativo")
        
        # Default values for common fields
        dias_semana = ["inativo"]
        horario = {"ligar": "inativo", "desligar": "inativo"}
        temperatura = "inativo"
        percentagem_abertura = "inativo"

        if estado == "ativo":
            dias_semana = parametros.get("dias_semana", ["inativo"])
            horario = parametros.get("horario", {"ligar": "inativo", "desligar": "inativo"})
            
            if dispositivo == "ar_condicionado":
                temperatura = parametros.get("temperatura", 23.0)
                try:
                    temperatura = float(temperatura)
                except ValueError:
                    temperatura = 23.0  # valor padrão se a conversão falhar
            
            elif dispositivo == "estores":
                percentagem_abertura = parametros.get("percentagem_abertura", 0)
                try:
                    percentagem_abertura = float(percentagem_abertura)
                except ValueError:
                    percentagem_abertura = 0  # valor padrão se a conversão falhar

        if dispositivo == "ar_condicionado":
            agendamento = {
                "estado": estado,
                "dias_semana": dias_semana,
                "horario": horario,
                "temperatura": temperatura
            }
        
        elif dispositivo == "estores":
            horario = {
                "hora subir": horario.get("ligar", "inativo"),
                "hora descer": horario.get("desligar", "inativo")
            }
            agendamento = {
                "estado": estado,
                "dias_semana": dias_semana,
                "horario": horario,
                "percentagem_abertura": percentagem_abertura
            }
        
        elif dispositivo == "luzes":
            agendamento = {
                "estado": estado,
                "dias_semana": dias_semana,
                "horario": horario
            }
        
        self.bd_.armazenar_parametros(dispositivo, "parametrizacao", agendamento)
        print(f"Parâmetros do {dispositivo}: {agendamento}")


    def tratar_ar_condicionado(self, dados, origem):
        estado = dados.get('estado')
        comando = {"ar_condicionado": "ligar" if estado == "ligar" else "desligar"}
        estado_armazenar = "ligado" if estado == "ligar" else "desligado"

        # Armazenar o estado do ar condicionado no banco de dados como 'ligado' ou 'desligado'
        self.bd_.armazenar_dados("ar_condicionado", "estado", {"ar_condicionado": estado_armazenar})

        log_dados = {
            "hora": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "instrucao": comando["ar_condicionado"],
            "origem": origem,
            "Parametros Programação": self.bd_.recuperar_dados("ar_condicionado", "parametrizacao")
        }
        self.bd_.registrar_log("ar_condicionado", log_dados)

        # Executar o comando
        self.preparar_comando("ar_condicionado", comando)

    def enviar_parametrizacao(self, dispositivo):
        parametros = self.bd_.recuperar_parametros(dispositivo, "parametrizacao")
        if parametros:
            mensagem = {
                "dispositivo": dispositivo,
                "parametrizacao": parametros,
            }
            print(f'Parâmetros enviados para {dispositivo}: {mensagem}')
            self.encaminhar_dados(TOPICO_RESPOSTA_PARAMETRIZACAO_APP, mensagem)
        else:
            print(f"Erro: Parâmetros não encontrados para {dispositivo}")

    def preparar_armazenamento(self, colecao, documento, dados):
        self.bd_.armazenar_dados(colecao, documento, dados)

    def preparar_comando(self, dispositivo, comando):
        resultado = self.dispositivo_.executar_comando(dispositivo, comando)
        self.preparar_armazenamento(dispositivo, "estado", resultado)
        self.encaminhar_dados(f"comando/{dispositivo}", resultado)

    def encaminhar_dados(self, topico, dados):
        print(f'Publicando mensagem no tópico {topico}: {dados}')
        self.mqtt_client.client.publish(topico, json.dumps(dados))

    def verificar_agendamentos(self):
        while True:
            now = datetime.now()
            agendamentos = {
                "luzes": self.bd_.recuperar_dados("luzes", "parametrizacao"),
                "estores": self.bd_.recuperar_dados("estores", "parametrizacao"),
                "ar_condicionado": self.bd_.recuperar_dados("ar_condicionado", "parametrizacao")
            }

            for dispositivo, parametros in agendamentos.items():
                if parametros and parametros['estado'] == 'ativo':
                    dias_semana = [dia.lower() for dia in parametros.get('dias_semana', [])]
                    horario = parametros.get('horario', {})

                    if now.strftime('%A').lower() in dias_semana:
                        if dispositivo == "estores":
                            abrir_horario = horario.get('hora subir')
                            fechar_horario = horario.get('hora descer')

                            if abrir_horario == now.strftime('%H:%M'):
                                self.processar_mensagem(TOPICO_APP, json.dumps({
                                    "instrucao": "Ordem",
                                    "parametros": {
                                        dispositivo: "subir"
                                    }
                                }))

                            if fechar_horario == now.strftime('%H:%M'):
                                self.processar_mensagem(TOPICO_APP, json.dumps({
                                    "instrucao": "Ordem",
                                    "parametros": {
                                        dispositivo: "descer"
                                    }
                                }))
                        else:
                            ligar_horario = horario.get('ligar')
                            desligar_horario = horario.get('desligar')

                            if ligar_horario == now.strftime('%H:%M'):
                                self.processar_mensagem(TOPICO_APP, json.dumps({
                                    "instrucao": "Ordem",
                                    "parametros": {
                                        dispositivo: "ligar"
                                    }
                                }))

                            if desligar_horario == now.strftime('%H:%M'):
                                self.processar_mensagem(TOPICO_APP, json.dumps({
                                    "instrucao": "Ordem",
                                    "parametros": {
                                        dispositivo: "desligar"
                                    }
                                }))
            time.sleep(60)

    def enviar_estado_continuo(self):
        while True:
            self.enviar_estado_dispositivos()
            self.verificar_temperatura()
            time.sleep(30)

    def enviar_estado_dispositivos(self):
        dispositivos = ["luzes", "estores", "ar_condicionado"]
        for dispositivo in dispositivos:
            estado = self.bd_.recuperar_dados(dispositivo, "estado")
            parametros = self.bd_.recuperar_parametros(dispositivo, "parametrizacao")
            mensagem_estado = {
                "dispositivo": dispositivo,
                "estado": estado,
                "parametrizacao": parametros
            }
            self.encaminhar_dados(TOPICO_RESPOSTA_APP, mensagem_estado)

    def adicionar_user(self, username, password):
        resultado = self.bd_.adicionar_user(username, password)
        self.encaminhar_dados(f"resposta/{TOPICO_APP}", resultado)

    def alterar_user(self, old_username, new_username, new_password):
        resultado = self.bd_.alterar_user(old_username, new_username, new_password)
        self.encaminhar_dados(f"resposta/{TOPICO_APP}", resultado)

    def remover_user(self, username):
        resultado = self.bd_.remover_user(username)
        self.encaminhar_dados(f"resposta/{TOPICO_APP}", resultado)

class Dispositivo_:
    def __init__(self, mqtt_client):
        self.mqtt_client = mqtt_client

    def executar_comando(self, dispositivo, comando):
        global timer_operacao_subida, timer_operacao_descida, tempo_restante_subida, tempo_restante_descida, estado_i
        global timer_s, timer_d

        if dispositivo == "estores":
            if comando["estores"] == "descer":
                if timer_operacao_subida != 0:
                    self.interromper_subida()
                self.iniciar_descida()
            elif comando["estores"] == "parar":
                if timer_operacao_descida != 0:
                    self.interromper_descida()
                elif timer_operacao_subida != 0:
                    self.interromper_subida()
            elif comando["estores"] == "subir":
                if timer_operacao_descida != 0:
                    self.interromper_descida()
                self.iniciar_subida()

        elif dispositivo == "luzes":
            if comando["luzes"] == "ligar":
                self.publicar_instrucao(TOPICO_LUZES_I, '{"method": "Switch.Set", "params": {"id": 0, "on": true}}')
            elif comando["luzes"] == "desligar":
                self.publicar_instrucao(TOPICO_LUZES_I, '{"method": "Switch.Set", "params": {"id": 0, "on": false}}')
                
        elif dispositivo == "ar_condicionado":
            if comando["ar_condicionado"] == "ligar":
                self.publicar_instrucao(TOPICO_AR_CONDICIONADO_I, '{"method": "Switch.Set", "params": {"id": 0, "on": true}}')
            elif comando["ar_condicionado"] == "desligar":
                self.publicar_instrucao(TOPICO_AR_CONDICIONADO_I, '{"method": "Switch.Set", "params": {"id": 0, "on": false}}')
                

    def publicar_instrucao(self, mqtt_topic, mensagem):
        self.mqtt_client.client.publish(mqtt_topic, mensagem)

    def interromper_subida(self):
        global timer_operacao_subida, tempo_restante_subida, tempo_restante_descida, timer_s
        
        paragem = time.perf_counter()
        tempo_gasto = paragem - timer_operacao_subida
        timer_operacao_subida = 0
        tempo_restante_subida -= tempo_gasto
        tempo_restante_descida += tempo_gasto
        ajuste_tempo()
        if timer_s is not None:
            timer_s.cancel()
        self.configuracao()

    def interromper_descida(self):
        global timer_operacao_descida, tempo_restante_subida, tempo_restante_descida, timer_d

        paragem = time.perf_counter()
        tempo_gasto = paragem - timer_operacao_descida
        timer_operacao_descida = 0
        tempo_restante_descida -= tempo_gasto
        tempo_restante_subida += tempo_gasto
        ajuste_tempo()
        if timer_d is not None:
            timer_d.cancel()
        self.configuracao()

    def iniciar_descida(self):
        global timer_operacao_descida, tempo_restante_descida, timer_d, estado_i
        if tempo_restante_descida != 0:
            estado_i["Descer"] = "follow"
        if estado_i["Descer"] != "detached":
            timer_operacao_descida = time.perf_counter()
            self.publicar_instrucao(TOPICO_ESTORES_I, '{"method": "Switch.Set", "params": {"id": 0, "on": true}}')
            self.mqtt_client.inf_t.notificar_estado("estores", "descendo", {"percentagem_abertura": percentagem_abertura})
            timer_d = threading.Timer(tempo_restante_descida + 2, lambda: self.ajustar_tempo_apos_descida())
            timer_d.start()
        else:
            self.configuracao()

    def iniciar_subida(self):
        global timer_operacao_subida, tempo_restante_subida, timer_s, estado_i
        
        if tempo_restante_subida != 0:
            estado_i["Subir"] = "follow"
        if estado_i["Subir"] != "detached":
            timer_operacao_subida = time.perf_counter()
            self.publicar_instrucao(TOPICO_ESTORES_I, '{"method": "Switch.Set", "params": {"id": 1, "on": true}}')
            self.mqtt_client.inf_t.notificar_estado("estores", "subindo", {"percentagem_abertura": percentagem_abertura})
            timer_s = threading.Timer(tempo_restante_subida + 2, lambda: self.ajustar_tempo_apos_subida())
            timer_s.start()
        else:
            self.configuracao()

    def ajustar_tempo_apos_descida(self):
        global timer_operacao_descida, tempo_restante_subida, tempo_restante_descida
        tempo_gasto = time.perf_counter() - timer_operacao_descida
        tempo_restante_descida = max(0, tempo_restante_descida - tempo_gasto)
        tempo_restante_subida = TEMPO_OPERACAO - tempo_restante_descida
        timer_operacao_descida = 0
        self.configuracao()

    def ajustar_tempo_apos_subida(self):
        global timer_operacao_subida, tempo_restante_subida, tempo_restante_descida
        tempo_gasto = time.perf_counter() - timer_operacao_subida
        tempo_restante_subida = max(0, tempo_restante_subida - tempo_gasto)
        tempo_restante_descida = TEMPO_OPERACAO - tempo_restante_subida
        timer_operacao_subida = 0
        self.configuracao()
        
    def armazenar_percentagem_abertura(self, percentagem_abertura):
        self.mqtt_client.inf_t.bd_.armazenar_dados("estores", "estado", {"percentagem_abertura": percentagem_abertura})

    def configuracao(self):
        global tempo_restante_descida, tempo_restante_subida, estado_i
        ajuste_tempo()
        percentagem_abertura = 1 - (tempo_restante_subida / TEMPO_OPERACAO)
        
        if tempo_restante_descida <= 0 or tempo_restante_subida >= TEMPO_OPERACAO:
            conf_descida = '{"method": "Switch.setConfig", "params": {"id": 0, "config": {"name": "DESCER","in_mode": "follow", "auto_off": false, "auto_off_delay": false}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_descida)
            estado_i["Subir"] = "follow"
            conf_descida = '{"method": "Switch.setConfig", "params": {"id": 0, "config": {"in_mode": "detached", "initial_state": "off"}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_descida)
            estado_i["Descer"] = "detached"
            conf_subida = f'{{"method": "Switch.setConfig", "params": {{"id": 1, "config": {{"name": "SUBIR","in_mode": "follow", "auto_off": true, "auto_off_delay": {TEMPO_OPERACAO}}}}}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_subida)
        elif tempo_restante_subida <= 0 or tempo_restante_descida >= TEMPO_OPERACAO:
            conf_subida = '{"method": "Switch.setConfig", "params": {"id": 1, "config": {"in_mode": "follow", "auto_off": false, "auto_off_delay": false}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_subida)
            conf_subida = f'{{"method": "Switch.setConfig", "params": {{"id": 1, "config": {{"in_mode": "follow", "auto_off": true, "auto_off_delay": {tempo_restante_subida}}}}}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_subida)
            conf_descida = f'{{"method": "Switch.setConfig", "params": {{"id": 0, "config": {{"in_mode": "follow", "auto_off": true, "auto_off_delay": {TEMPO_OPERACAO}}}}}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_descida)
            estado_i["Descer"] = "follow"
            conf_subida = '{"method": "Switch.setConfig", "params": {"id": 1, "config": {"in_mode": "detached","initial_state": "off"}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_subida)
            estado_i["Subir"] = "detached"
        else:
            conf_subida = f'{{"method": "Switch.setConfig", "params": {{"id": 1, "config": {{"in_mode": "follow", "auto_off": true, "auto_off_delay": {tempo_restante_subida}}}}}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_subida)
            estado_i["Subir"] = "follow"
            conf_descida = f'{{"method": "Switch.setConfig", "params": {{"id": 0, "config": {{"in_mode": "follow", "auto_off": true, "auto_off_delay": {tempo_restante_descida}}}}}}}'
            self.publicar_instrucao(TOPICO_ESTORES_I, conf_descida)
            estado_i["Descer"] = "follow"
        
        # Armazenar a percentagem de abertura atualizada
        self.armazenar_percentagem_abertura(percentagem_abertura)
        self.mqtt_client.inf_t.notificar_estado("estores", "parado", {"percentagem_abertura": percentagem_abertura})
        self.mqtt_client.inf_t.bd_.armazenar_dados("estores", "estado", {"funcionamento": "desligado"})

# Classe MQTT_
class MQTT_:
    def __init__(self, broker, port):
        try:
            # Iniciar o servidor Node.js com npm start
            self.node_process = subprocess.Popen(['npm', 'start'], cwd='/home/bruno/lei_leet/zigbee2mqtt')
        except Exception as e:
            print(f"Erro ao iniciar o servidor Node.js: {e}")

        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        
        try:
            self.client.connect(broker, port, 60)
        except Exception as e:
            print(f"Erro ao conectar ao broker MQTT: {e}")
        
        self.inf_t = Inf_t_(self)
        self.bd_ = BD_()
        self.inf_t.dispositivo_.configuracao()
        threading.Thread(target=self.inf_t.verificar_agendamentos).start()
        threading.Thread(target=self.inf_t.enviar_estado_continuo).start()

        print("\nMQTT está a correr no Raspberry Pi\n")

    def on_connect(self, client, userdata, flags, rc):
        try:
            client.subscribe(TOPICO_LUZES_N)
            client.subscribe(TOPICO_LUZES_I)
            client.subscribe(TOPICO_ESTORES_N)
            client.subscribe(TOPICO_ESTORES_I)
            client.subscribe(TOPICO_PORTA)
            client.subscribe(TOPICO_AR_CONDICIONADO_N)
            client.subscribe(TOPICO_AR_CONDICIONADO_I)
            client.subscribe(TOPICO_APP)
            client.subscribe(TOPICO_TEMPERATURA)
            client.subscribe(TOPICO_INICIO_PARAMETRIZACAO_APP)
            client.subscribe(TOPICO_ENVIO_PARAMETRIZACAO_APP)
        except Exception as e:
            print(f"Erro ao subscrever tópicos: {e}")

    def on_message(self, client, userdata, msg):
        try:
            self.inf_t.processar_mensagem(msg.topic, msg.payload)
            print(f'Mensagem recebida no tópico {msg.topic}: {msg.payload.decode()}')
        except Exception as e:
            print(f"Erro ao processar mensagem: {e}")

    def publicar_mensagem(self, topic, mensagem):
        try:
            self.client.publish(topic, mensagem)
            print(f'Mensagem enviada no tópico {topic}: {mensagem}')
        except Exception as e:
            print(f"Erro ao publicar mensagem no tópico {topic}: {e}")

    def iniciar(self):
        try:
            self.client.loop_forever()
        except KeyboardInterrupt:
            self.node_process.terminate()
            self.node_process.wait()
        except Exception as e:
            print(f"Erro ao executar o loop MQTT: {e}")
            self.node_process.terminate()
            self.node_process.wait()

# Inicialização
mqtt_ = MQTT_("192.168.1.239", 2224)
mqtt_.iniciar()
