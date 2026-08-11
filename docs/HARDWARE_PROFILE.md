# Perfil de hardware validado

Ver também `inventory/host-validated.yml`.

## Máquina de referência

| Recurso | Valor |
|---|---|
| OS | RHEL 10.2 (Coughlan) |
| CPU | Intel Core i9-14900K (32 threads) |
| RAM | 125 GiB |
| GPU | NVIDIA GeForce RTX 4060 8 GB |
| Driver | 580.173.02 |
| CUDA | 13.1.80 |
| Data mount | `/run/media/petterlopes/SSD930` |

## Implicações

- **Não** cabe full-GPU o kquant-17gb (~17 GB). Usar `--fit on`.
- RAM alta torna hybrid offload **viável** (~4 tok/s smoke com reasoning low).
- Para full-GPU fluido: GPU ≥24 GB (ou kquant menor custom — fora do pin oficial).

## Capacidade mínima sugerida para recriar

| Item | Mínimo prático |
|---|---|
| RAM | 32 GiB (64+ recomendado) |
| VRAM | 8 GiB (hybrid) / 24 GiB (confortável) |
| Disco | 25 GiB livres no `IALOCAL_DATA` |
| CUDA | toolkit compatível com a GPU |
