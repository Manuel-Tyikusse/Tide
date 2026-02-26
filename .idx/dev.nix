{ pkgs, ... }: {
  channel = "stable-24.05";
  
  packages = [
    pkgs.jdk17
    pkgs.unzip
    pkgs.android-tools
  ];

  env = {
    JAVA_HOME = "${pkgs.jdk17}";
    #vida louca
    # Aponta para um local com permissão de escrita
    ANDROID_HOME = pkgs.lib.mkForce "/home/user/android-sdk";
    ANDROID_SDK_ROOT = pkgs.lib.mkForce "/home/user/android-sdk";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    
    workspace = {
      onCreate = {
        # Criamos o diretório e instalamos o SDK onde temos permissão
        android-setup = ''
          mkdir -p /home/user/android-sdk
          export PATH=$PATH:${pkgs.android-tools}/bin
          
          # Aceita licenças e instala componentes no diretório de usuário
          yes | sdkmanager --licenses --sdk_root=/home/user/android-sdk
          sdkmanager --sdk_root=/home/user/android-sdk "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;26.1.10909125"
        '';
      };
      onStart = {
        # Log de debug para validar os caminhos no boot
        debug-vars = "echo 'LOG: ANDROID_HOME is set to' $ANDROID_HOME";
      };
    };

    previews = {
      enable = true;
      previews = {
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}