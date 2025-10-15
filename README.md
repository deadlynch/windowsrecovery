# Reriar Partição de Recuperação no Windows 11

Este script recria a partição de recuperação do Windows 11 e configura o Windows RE automaticamente.

## Requisitos

- Windows 11 em disco GPT
- Executar como **Administrador**
- **750 MB de espaço não alocado** no disco
- Arquivo `C:\Windows\System32\Recovery\winre.wim` existente

## Se `winre.wim` não existir

Você precisa copiar manualmente esse arquivo de uma ISO do Windows 11:

1. Monte a ISO oficial do Windows 11
2. Extraia `winre.wim` de `\Sources\install.wim` (usando DISM ou 7-Zip)
3. Copie para: `C:\Windows\System32\Recovery\winre.wim`

## Como usar

1. Libere ao menos 750 MB de espaço não alocado (via `diskmgmt.msc`)
2. Execute o script no PowerShell com permissões de administrador:

```powershell
C:\Caminho\para\recovery.ps1
