#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Extrai dados de XML da NF-e (nfeProc/NFe) para CSV.

Modos:
- itens: 1 linha por item (det)
- notas: 1 linha por nota (resumo)

Uso:
  python nfe_xml_to_csv.py --input "nota.xml" --output "saida.csv" --mode itens
  python nfe_xml_to_csv.py --input "pasta_xml" --output "itens.csv" --mode itens
"""

import argparse
import csv
import os
from pathlib import Path
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional, Iterable


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
    except ET.ParseError:
        return None


def _get_inf_nfe(root: ET.Element) -> Optional[ET.Element]:
    # Pode vir como <nfeProc><NFe><infNFe>... ou direto <NFe><infNFe>...
    inf = root.find(".//nfe:infNFe", namespaces=NS)
    return inf


def _extract_header(root: ET.Element) -> Dict[str, str]:
    inf = _get_inf_nfe(root)
    ide = _find(inf, "nfe:ide")
    emit = _find(inf, "nfe:emit")
    dest = _find(inf, "nfe:dest")
    total = _find(inf, "nfe:total/nfe:ICMSTot")

    # Chave costuma estar em protNFe/infProt/chNFe; fallback no atributo Id do infNFe
    ch = _findtext(root, ".//nfe:protNFe/nfe:infProt/nfe:chNFe", "")
    if not ch:
        inf_id = (inf.attrib.get("Id", "") if inf is not None else "")
        # Id vem como "NFe{CHAVE}"
        ch = inf_id.replace("NFe", "").strip()

    # Endereços (emit/dest)
    ender_emit = _find(emit, "nfe:enderEmit")
    ender_dest = _find(dest, "nfe:enderDest")

    data = {
        # Identificação
        "chNFe": ch,
        "nNF": _findtext(ide, "nfe:nNF"),
        "serie": _findtext(ide, "nfe:serie"),
        "dhEmi": _findtext(ide, "nfe:dhEmi"),
        "tpNF": _findtext(ide, "nfe:tpNF"),
        "natOp": _findtext(ide, "nfe:natOp"),
        "cUF": _findtext(ide, "nfe:cUF"),
        "cMunFG": _findtext(ide, "nfe:cMunFG"),

        # Emitente
        "emit_CNPJ": _findtext(emit, "nfe:CNPJ"),
        "emit_CPF": _findtext(emit, "nfe:CPF"),
        "emit_xNome": _findtext(emit, "nfe:xNome"),
        "emit_IE": _findtext(emit, "nfe:IE"),
        "emit_UF": _findtext(ender_emit, "nfe:UF"),
        "emit_xMun": _findtext(ender_emit, "nfe:xMun"),

        # Destinatário
        "dest_CNPJ": _findtext(dest, "nfe:CNPJ"),
        "dest_CPF": _findtext(dest, "nfe:CPF"),
        "dest_xNome": _findtext(dest, "nfe:xNome"),
        "dest_IE": _findtext(dest, "nfe:IE"),
        "dest_UF": _findtext(ender_dest, "nfe:UF"),
        "dest_xMun": _findtext(ender_dest, "nfe:xMun"),

        # Totais (ICMSTot)
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

        # Alguns valores úteis (podem não existir)
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


def iter_xml_files(input_path: Path) -> Iterable[Path]:
    if input_path.is_file():
        yield input_path
        return
    for p in sorted(input_path.rglob("*.xml")):
        if p.is_file():
            yield p


def write_csv(rows: List[Dict[str, str]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        # cria CSV vazio com nenhuma coluna
        out_path.write_text("", encoding="utf-8")
        return

    # Cabeçalho consistente
    fieldnames = list(rows[0].keys())
    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=";", quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="Arquivo XML ou pasta com XMLs")
    ap.add_argument("--output", required=True, help="Arquivo CSV de saída")
    ap.add_argument("--mode", choices=["itens", "notas"], default="itens", help="itens=1 linha por item; notas=1 linha por nota")
    args = ap.parse_args()

    input_path = Path(args.input).expanduser().resolve()
    out_path = Path(args.output).expanduser().resolve()

    all_rows: List[Dict[str, str]] = []

    for xml_file in iter_xml_files(input_path):
        root = _parse_xml(xml_file)
        if root is None:
            continue

        header = _extract_header(root)

        if args.mode == "notas":
            all_rows.append(header)
        else:
            items = _extract_items(root)
            for it in items:
                # junta cabeçalho + item na mesma linha
                row = {**header, **it}
                # opcional: rastrear arquivo de origem
                row["source_file"] = xml_file.name
                all_rows.append(row)

    write_csv(all_rows, out_path)
    print(f"OK: gerado {out_path} com {len(all_rows)} linha(s).")


if __name__ == "__main__":
    main()