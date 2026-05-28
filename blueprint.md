
# Blueprint do Projeto: Tide - Rede Social Autêntica

## 1. Visão Geral

**Tide** é uma rede social focada na autenticidade, onde a partilha de fotos e vídeos é feita exclusivamente através de captura instantânea pela câmera da aplicação, eliminando uploads da galeria. A arquitetura de backend é híbrida para otimizar custos e performance:

- **Supabase**: Backend principal para base de dados (PostgreSQL), autenticação, armazenamento de imagens (fotos de perfil e posts), e lógica de negócio (perfis, posts, likes, chats).
- **Appwrite**: Usado exclusivamente para o armazenamento de ficheiros de vídeo, que são mais pesados. O Supabase armazena apenas a URL do vídeo alojado no Appwrite.

## 2. Arquitetura de Backend (Implementada)

### Supabase

- **Autenticação**: Gerida pelo Supabase Auth. Um trigger `handle_new_user` cria automaticamente um perfil para cada novo registo.
- **Base de Dados (PostgreSQL)**:
    - `profiles`: Dados do utilizador (username, avatar_url, contadores).
    - `posts`: Registo de publicações (`user_id`, `media_url`, `caption`, `media_type`).
    - `likes`, `comments`, `followers`: Tabelas de relacionamento.
    - `chat_rooms`, `chat_participants`, `chat_messages`: Estrutura para o chat.
    - `notifications`: Para notificações de likes, comentários e novos seguidores.
- **Storage**:
    - `avatars`: Bucket para fotos de perfil.
    - `photos`: Bucket para imagens de posts.
- **Funções de Base de Dados (RPC)**:
    - `get_ranked_feed`: Lógica de ordenação do feed (algoritmo).
    - `update_engagement_score`: Atualiza a pontuação de um post com base em interações.
    - `create_or_get_private_chat`: Cria ou obtém uma sala de chat entre dois utilizadores.

### Appwrite

- **Storage**:
    - `videos`: Bucket público para todos os vídeos da aplicação.

## 3. Arquitetura do Código Flutter (Implementada)

A aplicação segue uma arquitetura limpa, com uma clara separação de responsabilidades.

- **`lib/core/clients/`**: Contém os clientes centralizados que comunicam com os backends:
    - **`TideClient` (`supabase_client.dart`)**: Ponto de acesso único para todas as operações do Supabase. Contém a lógica de negócio para autenticação, gestão de posts, perfis, chats, etc. Expõe métodos simples como `signIn()`, `createPost()`, `getPosts()`, etc.
    - **`AppwriteClient` (`appwrite_client.dart`)**: Responsável exclusivamente por fazer o upload de vídeos para o Appwrite Storage. Nota: ##Não está a funcionar

- **`lib/core/services/`**: Contém serviços que orquestram a lógica entre a UI e os clientes:
    - **`MediaService`**: Abstrai a complexidade do upload de mídia. Recebe um ficheiro e, com base na sua extensão, decide se deve usar o `TideClient` (para imagens) ou o `AppwriteClient` (para vídeos), retornando a URL final.
    - **`AlgorithmService`**: Contém a lógica de ordenação do feed. Utiliza o `TideClient` como fonte de dados para obter os posts e depois aplica a sua própria lógica de ranking (chamando a função `get_ranked_feed` do Supabase).

- **`lib/features/`**: Os módulos de UI da aplicação (Auth, Feed, Câmera, Chat, etc.) que dependem dos serviços e clientes do diretório `core` para executar ações, mantendo a UI limpa de lógica de negócio complexa.

## 4. Funcionalidades Implementadas (implementada)

- **Configuração do Projeto**: As dependências (`supabase_flutter`, `appwrite`, `camera`, etc.) e as credenciais de ambiente foram configuradas.

- **Backend Híbrido Funcional**:
    - Os scripts SQL para o Supabase foram validados.
    - A estrutura no Appwrite foi definida.

- **Arquitetura de Cliente Centralizada**:
    - `TideClient` e `AppwriteClient` foram implementados e estão a ser usados em toda a aplicação.  ##Nota: O appwrite não está a funcionar

- **Fluxo de Autenticação (Login/Registo)**:
    - A `LoginScreen` foi refatorada para usar `TideClient.signIn()` e `TideClient.signUp()`, centralizando a lógica de autenticação.

- **Fluxo de Criação de Posts (Câmera -> Publicação)**:
    - A `CameraScreen` captura a imagem ou vídeo.
    - A `PostPreviewScreen` foi refatorada para usar o `MediaService` para o upload e o `TideClient` para a criação do post na base de dados.

- **Visualização do Feed**:
    - A `FeedScreen` continua a funcionar com a sua lógica de paginação e UI, mas a sua fonte de dados, o `AlgorithmService`, foi refatorada para usar o `TideClient`.

- **Navegação e Badges**:
    - A `MainNavigation` foi refatorada para usar os métodos de stream do `TideClient` para mostrar o número de notificações e mensagens não lidas, limpando a lógica da UI.
