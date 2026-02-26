
-- Este script identifica utilizadores na tabela 'auth.users' que não têm um 
-- perfil correspondente na tabela 'public.profiles' e cria os perfis em falta.

INSERT INTO public.profiles (id, username, avatar_url, bio)
SELECT
    u.id,
    u.raw_user_meta_data->>'username' AS username,
    u.raw_user_meta_data->>'avatar_url' AS avatar_url,
    u.raw_user_meta_data->>'bio' AS bio
FROM
    auth.users u
LEFT JOIN
    public.profiles p ON u.id = p.id
WHERE
    p.id IS NULL; -- A condição chave: apenas insere se o perfil não existir
