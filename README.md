# Desmonta XML NF-e para CSV

Ferramenta automatizada para extração de dados de XML de Nota Fiscal Eletrônica (NF-e) para o formato CSV. Projetada para rodar em servidores Windows de forma agendada.

## 🚀 Funcionalidades

- **Processamento em Lote**: Varre a pasta `XML-Entrada` automaticamente.
- **Extração Completa**: Converte dados de cabeçalho (emitente, destinatário, totais) e itens da nota.
- **Organização Automática**: Move os arquivos XML processados para uma pasta de saída (`XML_Saida`).
- **Logs de Execução**: Monitoramento diário de sucessos e falhas em `Logs/`.
- **Portabilidade**: Funciona em qualquer diretório sem necessidade de configuração de caminhos fixos.

## 📁 Estrutura do Projeto

```text
/DesmontaXML
  ├── XML-Entrada/      # Coloque os arquivos XML originais aqui
  ├── CSV-Entrada/      # Onde os arquivos CSV gerados serão salvos
  ├── XML_Saida/        # Arquivos XML movidos após processamento
  ├── Logs/             # Registros de atividades (dia a dia)
  ├── Script/           # Código fonte (Python)
  └── run_nfe_processor.bat  # Atalho para execução e agendamento
```

## 🛠️ Instalação e Uso

1. Certifique-se de ter o **Python 3.x** instalado.
2. Clone este repositório.
3. Coloque um ou mais arquivos XML em `XML-Entrada`.
4. Execute o arquivo `run_nfe_processor.bat` clicando duas vezes ou via comando.
5. Verifique os resultados nas pastas `CSV-Entrada` e `XML_Saida`.

## ⏰ Agendamento no Windows

Para automação total, use o **Agendador de Tarefas do Windows**:
1. Crie uma nova tarefa básica.
2. Ação: "Iniciar um programa".
3. Programa/script: Selecione `run_nfe_processor.bat`.
4. Campo "Iniciar em": Coloque o caminho da pasta raiz do projeto.

---
Desenvolvido por Alexandre Nordin & Antigravity AI.
