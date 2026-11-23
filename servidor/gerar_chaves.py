"""Gera o par de chaves Ed25519 do servidor DCL Remoto no formato do hbbs.

id_ed25519      = base64(semente 32 bytes || chave pública 32 bytes)   -> SECRETO, só no servidor
id_ed25519.pub  = base64(chave pública 32 bytes)                        -> vai embutida no cliente

Mesmo formato de gen_sk() em src/common.rs (inclusive evita '/' e ':' na chave pública).
Uso: python gerar_chaves.py <pasta-destino>   (não sobrescreve chaves existentes)
"""
import base64
import os
import sys

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization


def gerar():
    for _ in range(300):
        sk = Ed25519PrivateKey.generate()
        seed = sk.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw,
                                serialization.NoEncryption())
        pk = sk.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
        pk64 = base64.b64encode(pk).decode()
        if "/" not in pk64 and ":" not in pk64:
            return base64.b64encode(seed + pk).decode(), pk64
    raise RuntimeError("não foi possível gerar chave sem '/'")


def main():
    destino = sys.argv[1]
    os.makedirs(destino, exist_ok=True)
    arq_sk = os.path.join(destino, "id_ed25519")
    arq_pk = arq_sk + ".pub"
    if os.path.exists(arq_sk) or os.path.exists(arq_pk):
        sys.exit(f"Já existem chaves em {destino}; nada foi alterado.")
    sk64, pk64 = gerar()
    with open(arq_sk, "w", newline="") as f:
        f.write(sk64)
    with open(arq_pk, "w", newline="") as f:
        f.write(pk64)
    print("Chave pública:", pk64)


if __name__ == "__main__":
    main()
