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

## 📝 Layout do CSV (dados_xml.csv)

O arquivo gerado consolida os dados em 4 blocos estruturais. A primeira coluna sempre indica o tipo de registro (1, 2, 3 ou 4).
Campos vazios ou inexistentes na nota são preenchidos com `0` (para valores numéricos) ou `@` (para textos).

### Bloco 1: Cabeçalho da Nota (Registro `1`)
Contém os dados gerais, emitente e destinatário.

| Posição | Campo | Posição | Campo | Posição | Campo |
|:---:|---|:---:|---|:---:|---|
| **1** | `Tipo (1)` | **8** | `cUF` | **15** | `emit_xMun` |
| **2** | `chNFe` | **9** | `cMunFG` | **16** | `dest_CNPJ` |
| **3** | `nNF` | **10** | `emit_CNPJ` | **17** | `dest_CPF` |
| **4** | `serie` | **11** | `emit_CPF` | **18** | `dest_xNome` |
| **5** | `dhEmi` | **12** | `emit_xNome` | **19** | `dest_IE` |
| **6** | `tpNF` | **13** | `emit_IE` | **20** | `dest_UF` |
| **7** | `natOp` | **14** | `emit_UF` | **21** | `dest_xMun` |
| | | | | **22** | `nome_arquivo` |

### Bloco 2: Itens da Nota (Registro `2`)
Um registro para cada produto da nota, incluindo dados detalhados e tributos.

| Posição | Campo | Posição | Campo | Posição | Campo |
|:---:|---|:---:|---|:---:|---|
| **1** | `Tipo (2)` | **19** | `icms_vICMS` | **37** | `cofins_CST` |
| **2** | `nItem` | **20** | `icms_modBCST` | **38** | `cofins_vBC` |
| **3** | `cProd` | **21** | `icms_pMVAST` | **39** | `cofins_pCOFINS` |
| **4** | `xProd` | **22** | `icms_pRedBCST` | **40** | `cofins_vCOFINS` |
| **5** | `NCM` | **23** | `icms_vBCST` | **41** | `ibscbs_CST` |
| **6** | `CFOP` | **24** | `icms_pICMSST` | **42** | `ibscbs_cClassTrib`|
| **7** | `uCom` | **25** | `icms_vICMSST` | **43** | `ibscbs_vBC` |
| **8** | `qCom` | **26** | `icms_vBCFCPST` | **44** | `ibscbs_pIBSUF` |
| **9** | `vUnCom` | **27** | `icms_pFCPST` | **45** | `ibscbs_vIBSUF` |
| **10** | `vProd_item` | **28** | `icms_vFCPST` | **46** | `ibscbs_pIBSMun` |
| **11** | `vTotTrib_item`| **29** | `ipi_CST` | **47** | `ibscbs_vIBSMun` |
| **12** | `lote` | **30** | `ipi_vBC` | **48** | `ibscbs_vIBS` |
| **13** | `icms_orig` | **31** | `ipi_pIPI` | **49** | `ibscbs_pCBS` |
| **14** | `icms_CST` | **32** | `ipi_vIPI` | **50** | `ibscbs_vCBS` |
| **15** | `icms_modBC` | **33** | `pis_CST` | **51** | `ii_vBC` |
| **16** | `icms_pRedBC` | **34** | `pis_vBC` | **52** | `ii_vDespAdu` |
| **17** | `icms_vBC` | **35** | `pis_pPIS` | **53** | `ii_vII` |
| **18** | `icms_pICMS` | **36** | `pis_vPIS` | **54** | `ii_vIOF` |

### Bloco 3: Totais da Nota (Registro `3`)
Contém a totalização dos valores.

| Posição | Campo | Posição | Campo |
|:---:|---|:---:|---|
| **1** | `Tipo (3)` | **7** | `vCOFINS` |
| **2** | `vProd` | **8** | `vBCIBSCBS` |
| **3** | `vNF` | **9** | `vIBS` |
| **4** | `vICMS` | **10** | `vCBS` |
| **5** | `vBC` | **11** | `vIPI` |
| **6** | `vPIS` | | |

### Bloco 4: Observações (Registro `4`)
Contém os dados adicionais do fisco e complementares da nota.

| Posição | Campo | Descrição |
|:---:|---|---|
| **1** | `Tipo (4)` | Fixo `4` |
| **2** | `Sequencial` | Sequencial do bloco de observação (1, 2, 3...) |
| **3** | `Texto` | Texto da observação (até 80 caracteres) |

## ⏰ Agendamento no Windows

Para automação total, use o **Agendador de Tarefas do Windows**:
1. Crie uma nova tarefa básica.
2. Ação: "Iniciar um programa".
3. Programa/script: Selecione `run_nfe_processor.bat`.
4. Campo "Iniciar em": Coloque o caminho da pasta raiz do projeto.

---
Desenvolvido por Alexandre Nordin & Antigravity AI.
