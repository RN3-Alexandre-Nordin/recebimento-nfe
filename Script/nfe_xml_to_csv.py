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
FOLDER_ARCHIVE = BASE_DIR / "XML_Saida"
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


def _extract_header(root: ET.Element) -> Dict[str, str]:
    inf = _get_inf_nfe(root)
    ide = _find(inf, "nfe:ide")
    emit = _find(inf, "nfe:emit")
    dest = _find(inf, "nfe:dest")
    total = _find(inf, "nfe:total/nfe:ICMSTot")

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
        "dhEmi": _findtext(ide, "nfe:dhEmi"),
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
    }
    return data


def _extract_items(root: ET.Element) -> List[Dict[str, str]]:
    inf = _get_inf_nfe(root)
    dets = _findall(inf, "nfe:det")
    items: List[Dict[str, str]] = []

    for det in dets:
        n_item = det.attrib.get("nItem", "").strip()
        prod = _find(det, "nfe:prod")
        imposto = _find(det, "nfe:imposto")
        vTotTrib = _findtext(imposto, "nfe:vTotTrib", "")

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
            "vTotTrib_item": vTotTrib,
        }
        items.append(item)

    return items


def write_csv(rows: List[Dict[str, str]], out_path: Path) -> bool:
    try:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        if not rows:
            logging.warning(f"Nenhum dado extraído para {out_path.name}")
            return False

        fieldnames = list(rows[0].keys())
        with out_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=";", quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()
            writer.writerows(rows)
        return True
    except Exception as e:
        logging.error(f"Erro ao escrever CSV {out_path.name}: {e}")
        return False


def process_xml(xml_file: Path, mode: str = "itens") -> bool:
    try:
        root = _parse_xml(xml_file)
        if root is None:
            return False

        header = _extract_header(root)
        rows: List[Dict[str, str]] = []

        if mode == "notas":
            rows.append(header)
        else:
            items = _extract_items(root)
            for it in items:
                row = {**header, **it}
                row["source_file"] = xml_file.name
                rows.append(row)

        csv_name = xml_file.with_suffix(".csv").name
        out_csv = FOLDER_OUTPUT / csv_name
        
        if write_csv(rows, out_csv):
            logging.info(f"Sucesso: {xml_file.name} -> {csv_name}")
            return True
        return False
    except Exception as e:
        logging.error(f"Erro no processamento de {xml_file.name}: {e}")
        return False


def main():
    # Cria pastas se não existirem
    for folder in [FOLDER_INPUT, FOLDER_OUTPUT, FOLDER_ARCHIVE, FOLDER_LOGS]:
        folder.mkdir(parents=True, exist_ok=True)

    xml_files = list(FOLDER_INPUT.glob("*.xml"))
    if not xml_files:
        logging.info("Nenhum arquivo XML encontrado para processar.")
        return

    logging.info(f"Iniciando processamento de {len(xml_files)} arquivos...")

    processed_count = 0
    for xml_file in xml_files:
        if process_xml(xml_file):
            # Move para a pasta de saída após sucesso
            target_path = FOLDER_ARCHIVE / xml_file.name
            try:
                # Se já existir um arquivo com o mesmo nome na saída, remove antes de mover (ou poderia renomear)
                if target_path.exists():
                    target_path.unlink()
                shutil.move(str(xml_file), str(target_path))
                processed_count += 1
            except Exception as e:
                logging.error(f"Erro ao mover arquivo {xml_file.name} para saída: {e}")

    logging.info(f"Processamento concluído. {processed_count} arquivos movidos para {FOLDER_ARCHIVE.name}.")


if __name__ == "__main__":
    main()