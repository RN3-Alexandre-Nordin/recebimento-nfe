#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Extrai dados de XML da NF-e (nfeProc/NFe) para CSV.
Automatizado para ler de uma pasta, processar e mover os arquivos.
"""

import argparse
import csv
import os
import shutil
import logging
from datetime import datetime
from pathlib import Path
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional, Iterable


# --- Configurações de Pastas (Relativas) ---
# O BASE_DIR agora é detectado automaticamente como a pasta raiz (um nível acima de 'Script')
BASE_DIR = Path(__file__).resolve().parent.parent
FOLDER_INPUT = BASE_DIR / "XML-Entrada"
FOLDER_OUTPUT = BASE_DIR / "CSV-Entrada"
FOLDER_ARCHIVE = BASE_DIR / "XML-Saida"
FOLDER_LOGS = BASE_DIR / "Logs"

# --- Configuração de Log ---
LOG_FILE = FOLDER_LOGS / f"processamento_{datetime.now().strftime('%Y%m%d')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler()
    ]
)

NFE_NS = "http://www.portalfiscal.inf.br/nfe"
NS = {"nfe": NFE_NS}


def _findtext(node: Optional[ET.Element], xpath: str, default: str = "") -> str:
    if node is None:
        return default
    val = node.findtext(xpath, default=default, namespaces=NS)
    return (val or default).strip()


def _find(node: Optional[ET.Element], xpath: str) -> Optional[ET.Element]:
    if node is None:
        return None
    return node.find(xpath, namespaces=NS)


def _findall(node: Optional[ET.Element], xpath: str) -> List[ET.Element]:
    if node is None:
        return []
    return node.findall(xpath, namespaces=NS)


def _parse_xml(path: Path) -> Optional[ET.Element]:
    try:
        tree = ET.parse(path)
        return tree.getroot()
    except Exception as e:
        logging.error(f"Erro ao ler XML {path.name}: {e}")
        return None


def _get_inf_nfe(root: ET.Element) -> Optional[ET.Element]:
    inf = root.find(".//nfe:infNFe", namespaces=NS)
    return inf


def _format_date_only(date_str: str) -> str:
    """
    Extrai apenas a data no formato YYYY/MM/DD de uma string ISO 8601 completa.
    Exemplo: '2026-02-27T17:17:00-03:00' -> '2026/02/27'
    """
    if not date_str:
        return ""
    # Extrai apenas os primeiros 10 caracteres (YYYY-MM-DD) e substitui - por /
    date_part = date_str[:10]
    return date_part.replace("-", "/") if len(date_part) == 10 else date_str


def _extract_header(root: ET.Element) -> Dict[str, str]:
    inf = _get_inf_nfe(root)
    ide = _find(inf, "nfe:ide")
    emit = _find(inf, "nfe:emit")
    dest = _find(inf, "nfe:dest")
    total = _find(inf, "nfe:total/nfe:ICMSTot")
    ibs_tot = _find(inf, "nfe:total/nfe:IBSCBSTot")

    ch = _findtext(root, ".//nfe:protNFe/nfe:infProt/nfe:chNFe", "")
    if not ch:
        inf_id = (inf.attrib.get("Id", "") if inf is not None else "")
        ch = inf_id.replace("NFe", "").strip()

    ender_emit = _find(emit, "nfe:enderEmit")
    ender_dest = _find(dest, "nfe:enderDest")

    data = {
        "chNFe": ch,
        "nNF": _findtext(ide, "nfe:nNF"),
        "serie": _findtext(ide, "nfe:serie"),
        "dhEmi": _format_date_only(_findtext(ide, "nfe:dhEmi")),
        "tpNF": _findtext(ide, "nfe:tpNF"),
        "natOp": _findtext(ide, "nfe:natOp"),
        "cUF": _findtext(ide, "nfe:cUF"),
        "cMunFG": _findtext(ide, "nfe:cMunFG"),
        "emit_CNPJ": _findtext(emit, "nfe:CNPJ"),
        "emit_CPF": _findtext(emit, "nfe:CPF"),
        "emit_xNome": _findtext(emit, "nfe:xNome"),
        "emit_IE": _findtext(emit, "nfe:IE"),
        "emit_UF": _findtext(ender_emit, "nfe:UF"),
        "emit_xMun": _findtext(ender_emit, "nfe:xMun"),
        "dest_CNPJ": _findtext(dest, "nfe:CNPJ"),
        "dest_CPF": _findtext(dest, "nfe:CPF"),
        "dest_xNome": _findtext(dest, "nfe:xNome"),
        "dest_IE": _findtext(dest, "nfe:IE"),
        "dest_UF": _findtext(ender_dest, "nfe:UF"),
        "dest_xMun": _findtext(ender_dest, "nfe:xMun"),
        "vProd": _findtext(total, "nfe:vProd"),
        "vNF": _findtext(total, "nfe:vNF"),
        "vICMS": _findtext(total, "nfe:vICMS"),
        "vBC": _findtext(total, "nfe:vBC"),
        "vPIS": _findtext(total, "nfe:vPIS"),
        "vCOFINS": _findtext(total, "nfe:vCOFINS"),
        "vBCIBSCBS": _findtext(ibs_tot, "nfe:vBCIBSCBS"),
        "vIBS": _findtext(ibs_tot, "nfe:gIBS/nfe:vIBS"),
        "vCBS": _findtext(ibs_tot, "nfe:gCBS/nfe:vCBS"),
        "vIPI": _findtext(total, "nfe:vIPI"),
    }
    
    infAdic = _find(inf, "nfe:infAdic")
    infAdFisco = _findtext(infAdic, "nfe:infAdFisco")
    infCpl = _findtext(infAdic, "nfe:infCpl")
    obs = ""
    if infAdFisco:
        obs += infAdFisco
    if infCpl:
        obs += (" " if obs else "") + infCpl
    data["observacao"] = obs

    return data


def _get_tax_node_data(tax_group_node: Optional[ET.Element], prefix: str) -> Dict[str, str]:
    """
    Achata os dados de um grupo de imposto (ex: ICMS, IPI) procurando o nó de CST/CSOSN
    e extraindo todos os seus sub-elementos.
    Para IBSCBS, extrai diretamente do nó grupo pois não tem sub-nó CST.
    Para IPI, trata o caso especial de IPINT.
    """
    data = {}
    if tax_group_node is None:
        return data

    if prefix == "ibscbs":
        # IBSCBS é plano, sem sub-nó CST
        for child in tax_group_node:
            tag_name = child.tag.replace(f"{{{NFE_NS}}}", "")
            if tag_name == "gIBSCBS":
                # Extrair sub-elementos de gIBSCBS
                for subchild in child:
                    sub_tag = subchild.tag.replace(f"{{{NFE_NS}}}", "")
                    if sub_tag in ["gIBSUF", "gIBSMun", "gCBS"]:
                        # Extrair sub-sub-elementos
                        for subsub in subchild:
                            subsub_tag = subsub.tag.replace(f"{{{NFE_NS}}}", "")
                            data[f"{prefix}_{subsub_tag}"] = (subsub.text or "").strip()
                    else:
                        data[f"{prefix}_{sub_tag}"] = (subchild.text or "").strip()
            else:
                data[f"{prefix}_{tag_name}"] = (child.text or "").strip()
    elif prefix == "ipi":
        # Para IPI, grupo é IPINT, CST é direto
        data[f"{prefix}_group"] = "IPINT"
        data[f"{prefix}_CST"] = _findtext(tax_group_node, "nfe:IPINT/nfe:CST", "")
    elif prefix == "ii":
        # Para II (Imposto de Importação)
        data[f"{prefix}_vBC"] = _findtext(tax_group_node, "nfe:vBC", "")
        data[f"{prefix}_vDespAdu"] = _findtext(tax_group_node, "nfe:vDespAdu", "")
        data[f"{prefix}_vII"] = _findtext(tax_group_node, "nfe:vII", "")
        data[f"{prefix}_vIOF"] = _findtext(tax_group_node, "nfe:vIOF", "")
    else:
        # O grupo de imposto (ex: <ICMS>) geralmente tem um único filho (ex: <ICMS00>, <ICMSSN101>)
        cst_node = None
        for child in tax_group_node:
            cst_node = child
            break

        if cst_node is not None:
            # Pega o nome do nó de situação tributária (ex: ICMS00)
            data[f"{prefix}_group"] = cst_node.tag.replace(f"{{{NFE_NS}}}", "")
            for child in cst_node:
                tag_name = child.tag.replace(f"{{{NFE_NS}}}", "")
                data[f"{prefix}_{tag_name}"] = (child.text or "").strip()
    
    return data


def _extract_items(root: ET.Element) -> List[Dict[str, str]]:
    inf = _get_inf_nfe(root)
    dets = _findall(inf, "nfe:det")
    items: List[Dict[str, str]] = []

    for det in dets:
        n_item = det.attrib.get("nItem", "").strip()
        prod = _find(det, "nfe:prod")
        imposto = _find(det, "nfe:imposto")

        # Dados básicos do item
        item = {
            "nItem": n_item,
            "cProd": _findtext(prod, "nfe:cProd"),
            "xProd": _findtext(prod, "nfe:xProd"),
            "NCM": _findtext(prod, "nfe:NCM"),
            "CFOP": _findtext(prod, "nfe:CFOP"),
            "uCom": _findtext(prod, "nfe:uCom"),
            "qCom": _findtext(prod, "nfe:qCom"),
            "vUnCom": _findtext(prod, "nfe:vUnCom"),
            "vProd_item": _findtext(prod, "nfe:vProd"),
            "vTotTrib_item": _findtext(imposto, "nfe:vTotTrib"),
            "lote": _findtext(prod, "nfe:rastro/nfe:nLote", "@"),
        }

        # Extração detalhada de impostos
        if imposto is not None:
            group_mapping = {
                "icms": "nfe:ICMS",
                "ipi": "nfe:IPI",
                "pis": "nfe:PIS",
                "cofins": "nfe:COFINS",
                "ibscbs": "nfe:IBSCBS",
                "ii": "nfe:II"
            }
            for prefix, xpath in group_mapping.items():
                tax_node = _find(imposto, xpath)
                tax_data = _get_tax_node_data(tax_node, prefix)
                item.update(tax_data)

        items.append(item)

    return items


def _fill_values(data: Dict[str, str], fields: List[str], numeric_fields: set) -> List[str]:
    row = []
    for f in fields:
        val = data.get(f, "")
        if not val:
            row.append("0" if f in numeric_fields else "@")
        else:
            row.append(val)
    return row

def process_xml(xml_file: Path) -> Optional[List[List[str]]]:
    try:
        root = _parse_xml(xml_file)
        if root is None:
            return None

        header_data = _extract_header(root)
        header_data["nome_arquivo"] = xml_file.name
        items_data = _extract_items(root)
        
        all_rows = []

        # --- Bloco 1: Cabeçalho ---
        b1_fields = [
            "chNFe", "nNF", "serie", "dhEmi", "tpNF", "natOp", "cUF", "cMunFG",
            "emit_CNPJ", "emit_CPF", "emit_xNome", "emit_IE", "emit_UF", "emit_xMun",
            "dest_CNPJ", "dest_CPF", "dest_xNome", "dest_IE", "dest_UF", "dest_xMun", "nome_arquivo"
        ]
        b1_num = {"nNF", "serie", "tpNF", "cUF", "cMunFG"}
        b1_row = ["1"] + _fill_values(header_data, b1_fields, b1_num)
        all_rows.append(b1_row)

        # --- Bloco 2: Itens ---
        b2_fields = [
            "nItem", "cProd", "xProd", "NCM", "CFOP", "uCom", "qCom", "vUnCom", "vProd_item", "vTotTrib_item", "lote",
            "icms_orig", "icms_CST", "icms_modBC", "icms_pRedBC", "icms_vBC", "icms_pICMS", "icms_vICMS",
            "icms_modBCST", "icms_pMVAST", "icms_pRedBCST", "icms_vBCST", "icms_pICMSST", "icms_vICMSST", "icms_vBCFCPST", "icms_pFCPST", "icms_vFCPST",
            "ipi_CST", "ipi_vBC", "ipi_pIPI", "ipi_vIPI",
            "pis_CST", "pis_vBC", "pis_pPIS", "pis_vPIS",
            "cofins_CST", "cofins_vBC", "cofins_pCOFINS", "cofins_vCOFINS",
            "ibscbs_CST", "ibscbs_cClassTrib", "ibscbs_vBC", "ibscbs_pIBSUF", "ibscbs_vIBSUF", "ibscbs_pIBSMun", "ibscbs_vIBSMun", "ibscbs_vIBS", "ibscbs_pCBS", "ibscbs_vCBS",
            "ii_vBC", "ii_vDespAdu", "ii_vII", "ii_vIOF"
        ]
        b2_num = {
            "nItem", "qCom", "vUnCom", "vProd_item", "vTotTrib_item",
            "icms_orig", "icms_CST", "icms_modBC", "icms_pRedBC", "icms_vBC", "icms_pICMS", "icms_vICMS",
            "icms_modBCST", "icms_pMVAST", "icms_pRedBCST", "icms_vBCST", "icms_pICMSST", "icms_vICMSST", "icms_vBCFCPST", "icms_pFCPST", "icms_vFCPST",
            "ipi_CST", "ipi_vBC", "ipi_pIPI", "ipi_vIPI",
            "pis_CST", "pis_vBC", "pis_pPIS", "pis_vPIS",
            "cofins_CST", "cofins_vBC", "cofins_pCOFINS", "cofins_vCOFINS",
            "ibscbs_CST", "ibscbs_vBC", "ibscbs_pIBSUF", "ibscbs_vIBSUF", "ibscbs_pIBSMun", "ibscbs_vIBSMun", "ibscbs_vIBS", "ibscbs_pCBS", "ibscbs_vCBS",
            "ii_vBC", "ii_vDespAdu", "ii_vII", "ii_vIOF"
        }
        for item in items_data:
            b2_row = ["2"] + _fill_values(item, b2_fields, b2_num)
            all_rows.append(b2_row)

        # --- Bloco 3: Totais ---
        b3_fields = ["vProd", "vNF", "vICMS", "vBC", "vPIS", "vCOFINS", "vBCIBSCBS", "vIBS", "vCBS", "vIPI"]
        b3_num = {"vProd", "vNF", "vICMS", "vBC", "vPIS", "vCOFINS", "vBCIBSCBS", "vIBS", "vCBS", "vIPI"}
        b3_row = ["3"] + _fill_values(header_data, b3_fields, b3_num)
        all_rows.append(b3_row)

        # --- Bloco 4: Observações ---
        obs_text = header_data.get("observacao", "")
        if obs_text and obs_text != "@":
            chunk_size = 80
            chunks = [obs_text[i:i+chunk_size] for i in range(0, len(obs_text), chunk_size)]
            for idx, chunk in enumerate(chunks, start=1):
                all_rows.append(["4", str(idx), chunk])

        return all_rows
    except Exception as e:
        logging.error(f"Erro no processamento de {xml_file.name}: {e}")
        return None


def main():
    # Cria pastas se não existirem
    for folder in [FOLDER_INPUT, FOLDER_OUTPUT, FOLDER_ARCHIVE, FOLDER_LOGS]:
        folder.mkdir(parents=True, exist_ok=True)

    xml_files = list(FOLDER_INPUT.glob("*.xml"))
    if not xml_files:
        logging.info("Nenhum arquivo XML encontrado para processar.")
        return

    logging.info(f"Iniciando processamento de {len(xml_files)} arquivos...")

    out_csv_path = FOLDER_OUTPUT / "dados_xml.csv"
    processed_count = 0

    try:
        # Abre o arquivo CSV único em modo de escrita (sobrescreve o existente)
        with out_csv_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f, delimiter=";", quoting=csv.QUOTE_MINIMAL)
            
            for xml_file in xml_files:
                rows_to_write = process_xml(xml_file)
                
                if rows_to_write is not None:
                    writer.writerows(rows_to_write)
                    # Move para a pasta de saída após sucesso
                    target_path = FOLDER_ARCHIVE / xml_file.name
                    try:
                        if target_path.exists():
                            target_path.unlink()
                        shutil.move(str(xml_file), str(target_path))
                        processed_count += 1
                        logging.info(f"Sucesso: {xml_file.name} adicionado ao CSV único.")
                    except Exception as e:
                        logging.error(f"Erro ao mover arquivo {xml_file.name} para saída: {e}")
                else:
                    logging.warning(f"Falha ao processar {xml_file.name}, ignorado.")

    except Exception as e:
        logging.error(f"Erro ao abrir/escrever no arquivo {out_csv_path.name}: {e}")

    logging.info(f"Processamento concluído. {processed_count} arquivos processados com sucesso.")


if __name__ == "__main__":
    main()