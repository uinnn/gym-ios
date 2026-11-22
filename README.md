# Gym — app iOS de saúde física e mental

Passo 1: ler o peso da balança de bioimpedância via Bluetooth.

## Como compilar sem Mac

O GitHub Actions compila o app num macOS na nuvem e gera `Gym.ipa`.

1. Crie um repositório no GitHub (público = minutos de macOS grátis) e envie esta pasta.
2. Aba **Actions** → workflow **Build IPA** → execução mais recente → baixe o artefato `Gym-ipa`.

## Como instalar no iPhone (Windows)

1. Instale o **iTunes** (versão do site da Apple, não da Microsoft Store) e o **Sideloadly** (sideloadly.io).
2. Ligue o iPhone no PC por cabo e toque em "Confiar".
3. No Sideloadly: arraste o `Gym.ipa`, informe seu Apple ID e clique em Start.
4. No iPhone: Ajustes → Geral → VPN e Gerenciamento de Dispositivos → confie no seu Apple ID.
5. Em iOS 16+: ative Ajustes → Privacidade e Segurança → **Modo de Desenvolvedor**.

Com Apple ID gratuito o app expira em 7 dias; basta reinstalar.

## Como usar (descobrir o formato da balança)

1. Abra o app e permita o Bluetooth.
2. Suba na balança. Ela aparece na lista (nomes comuns: Chipsea, OKOK, Scale).
3. Toque nela. Cada pacote recebido mostra botões com valores "plausíveis" de peso.
4. Toque no valor igual ao do visor. O formato fica salvo e o peso passa a aparecer.
5. Se nada bater, toque em **Conectar** e repita. Use **Compartilhar log bruto** para análise.

Próximo passo: decodificar a impedância e calcular gordura, músculo, água etc. (exige altura, idade e sexo).
