
-- ### SCHEMA FINAL E COMPLETO PARA O SUPABASE ###

-- --- 1. TABELAS (COM SUPORTE PARA RESPOSTAS E LIKES EM COMENTÁRIOS) ---

CREATE TABLE IF NOT EXISTS profiles ( id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE, username TEXT UNIQUE NOT NULL, avatar_url TEXT, bio TEXT, updated_at TIMESTAMPTZ DEFAULT NOW(), posts_count INT DEFAULT 0, followers_count INT DEFAULT 0, following_count INT DEFAULT 0, CONSTRAINT username_length CHECK (char_length(username) >= 3) );
CREATE TABLE IF NOT EXISTS posts ( id SERIAL PRIMARY KEY, user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, media_url TEXT NOT NULL, thumbnail_url TEXT, caption TEXT, media_type TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW(), likes_count INT DEFAULT 0, comments_count INT DEFAULT 0 );
CREATE TABLE IF NOT EXISTS followers ( follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (follower_id, following_id) );
CREATE TABLE IF NOT EXISTS likes ( user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, post_id INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (user_id, post_id) );

-- Tabela de Comentários melhorada
CREATE TABLE IF NOT EXISTS comments (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  post_id INT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  content TEXT NOT NULL, 
  created_at TIMESTAMPTZ DEFAULT NOW(),
  parent_comment_id INT REFERENCES comments(id) ON DELETE CASCADE, -- Para respostas
  likes_count INT DEFAULT 0 -- Para likes em comentários
);

-- Nova tabela para likes em comentários
CREATE TABLE IF NOT EXISTS comment_likes (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  comment_id INT NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, comment_id)
);

CREATE TABLE IF NOT EXISTS notifications ( id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, post_id BIGINT REFERENCES public.posts(id) ON DELETE CASCADE, comment_id INT, type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'reply_comment', 'like_comment')), is_read BOOLEAN NOT NULL DEFAULT FALSE, CONSTRAINT unique_notification_per_action UNIQUE (receiver_id, sender_id, post_id, type, comment_id), CONSTRAINT sender_is_not_receiver CHECK (sender_id <> receiver_id) );
CREATE TABLE IF NOT EXISTS chat_rooms ( id SERIAL PRIMARY KEY, is_group BOOLEAN NOT NULL DEFAULT FALSE, group_name TEXT, group_avatar_url TEXT, created_by UUID REFERENCES profiles(id), created_at TIMESTAMPTZ DEFAULT NOW() );
CREATE TABLE IF NOT EXISTS chat_participants ( room_id INT NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE, user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, role TEXT DEFAULT 'member', joined_at TIMESTAMPTZ DEFAULT NOW(), PRIMARY KEY (room_id, user_id) );
CREATE TABLE IF NOT EXISTS chat_messages ( id BIGSERIAL PRIMARY KEY, room_id INT NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE, sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE, content TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW() );


-- --- 2. TRIGGERS & FUNÇÕES FINAIS ---

-- Limpeza geral de triggers e funções antigas
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users; DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TRIGGER IF EXISTS on_follow_created ON followers; DROP TRIGGER IF EXISTS on_follow_deleted ON followers; DROP FUNCTION IF EXISTS public.handle_new_follow(); DROP FUNCTION IF EXISTS public.handle_unfollow();
DROP TRIGGER IF EXISTS on_like_created ON likes; DROP FUNCTION IF EXISTS public.handle_new_like();
DROP TRIGGER IF EXISTS on_comment_created ON comments; DROP FUNCTION IF EXISTS public.handle_new_comment();
DROP TRIGGER IF EXISTS on_like_deleted ON likes; DROP FUNCTION IF EXISTS public.decrement_like_count();
DROP TRIGGER IF EXISTS on_comment_deleted ON comments; DROP FUNCTION IF EXISTS public.decrement_comment_count();
DROP TRIGGER IF EXISTS on_comment_like_created ON comment_likes; DROP TRIGGER IF EXISTS on_comment_like_deleted ON comment_likes; DROP FUNCTION IF EXISTS public.handle_new_comment_like(); DROP FUNCTION IF EXISTS public.handle_delete_comment_like();

-- Funções e Triggers existentes (corrigidos)
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER AS $$ BEGIN INSERT INTO public.profiles (id, username) VALUES (new.id, new.raw_user_meta_data->>'username'); RETURN new; END; $$ LANGUAGE plpgsql SECURITY DEFINER;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_follow() RETURNS TRIGGER AS $$ BEGIN UPDATE profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id; UPDATE profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id; INSERT INTO public.notifications(receiver_id, sender_id, type) VALUES(NEW.following_id, NEW.follower_id, 'follow'); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION public.handle_unfollow() RETURNS TRIGGER AS $$ BEGIN UPDATE profiles SET following_count = GREATEST(0, following_count - 1) WHERE id = OLD.follower_id; UPDATE profiles SET followers_count = GREATEST(0, followers_count - 1) WHERE id = OLD.following_id; RETURN OLD; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER on_follow_created AFTER INSERT ON followers FOR EACH ROW EXECUTE PROCEDURE handle_new_follow();
CREATE TRIGGER on_follow_deleted AFTER DELETE ON followers FOR EACH ROW EXECUTE PROCEDURE handle_unfollow();

CREATE OR REPLACE FUNCTION public.handle_new_like() RETURNS TRIGGER AS $$ DECLARE post_author_id UUID; BEGIN UPDATE posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id; SELECT user_id INTO post_author_id FROM posts WHERE id = NEW.post_id; IF post_author_id <> NEW.user_id THEN INSERT INTO public.notifications(receiver_id, sender_id, post_id, type) VALUES(post_author_id, NEW.user_id, NEW.post_id, 'like'); END IF; RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER on_like_created AFTER INSERT ON likes FOR EACH ROW EXECUTE PROCEDURE handle_new_like();

-- Função de comentários melhorada (distingue entre comentário e resposta)
CREATE OR REPLACE FUNCTION public.handle_new_comment() RETURNS TRIGGER AS $$ DECLARE post_author_id UUID; parent_comment_author_id UUID; BEGIN UPDATE posts SET comments_count = comments_count + 1 WHERE id = NEW.post_id; SELECT user_id INTO post_author_id FROM posts WHERE id = NEW.post_id; IF NEW.parent_comment_id IS NULL THEN IF post_author_id <> NEW.user_id THEN INSERT INTO public.notifications(receiver_id, sender_id, post_id, comment_id, type) VALUES(post_author_id, NEW.user_id, NEW.post_id, NEW.id, 'comment'); END IF; ELSE SELECT user_id INTO parent_comment_author_id FROM comments WHERE id = NEW.parent_comment_id; IF parent_comment_author_id <> NEW.user_id THEN INSERT INTO public.notifications(receiver_id, sender_id, post_id, comment_id, type) VALUES(parent_comment_author_id, NEW.user_id, NEW.post_id, NEW.parent_comment_id, 'reply_comment'); END IF; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER on_comment_created AFTER INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE handle_new_comment();

-- Novas funções para likes em comentários
CREATE OR REPLACE FUNCTION public.handle_new_comment_like() RETURNS TRIGGER AS $$ DECLARE comment_author_id UUID; BEGIN UPDATE comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id; SELECT user_id INTO comment_author_id FROM comments WHERE id = NEW.comment_id; IF comment_author_id <> NEW.user_id THEN INSERT INTO public.notifications(receiver_id, sender_id, post_id, comment_id, type) SELECT c.user_id, NEW.user_id, c.post_id, NEW.comment_id, 'like_comment' FROM comments c WHERE c.id = NEW.comment_id; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION public.handle_delete_comment_like() RETURNS TRIGGER AS $$ BEGIN UPDATE comments SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.comment_id; RETURN OLD; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER on_comment_like_created AFTER INSERT ON comment_likes FOR EACH ROW EXECUTE PROCEDURE handle_new_comment_like();
CREATE TRIGGER on_comment_like_deleted AFTER DELETE ON comment_likes FOR EACH ROW EXECUTE PROCEDURE handle_delete_comment_like();

-- Funções de decremento
CREATE OR REPLACE FUNCTION public.decrement_like_count() RETURNS TRIGGER AS $$ BEGIN UPDATE posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = OLD.post_id; RETURN OLD; END; $$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION public.decrement_comment_count() RETURNS TRIGGER AS $$ BEGIN UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = OLD.post_id; RETURN OLD; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER on_like_deleted AFTER DELETE ON likes FOR EACH ROW EXECUTE PROCEDURE decrement_like_count();
CREATE TRIGGER on_comment_deleted AFTER DELETE ON comments FOR EACH ROW EXECUTE PROCEDURE decrement_comment_count();


-- --- 3. POLÍTICAS DE SEGURANÇA (RLS) ---

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY; ALTER TABLE posts ENABLE ROW LEVEL SECURITY; ALTER TABLE followers ENABLE ROW LEVEL SECURITY; ALTER TABLE likes ENABLE ROW LEVEL SECURITY; ALTER TABLE comments ENABLE ROW LEVEL SECURITY; ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY; ALTER TABLE notifications ENABLE ROW LEVEL SECURITY; ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY; ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY; ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Políticas existentes são mantidas e novas são adicionadas
CREATE POLICY "Todos podem ver perfis" ON profiles FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem criar e gerir os seus perfis" ON profiles FOR ALL USING (auth.uid() = id);

CREATE POLICY "Todos podem ver posts" ON posts FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem criar, atualizar e apagar os seus posts" ON posts FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Todos podem ver relações de seguir" ON followers FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem seguir e deixar de seguir" ON followers FOR ALL USING (auth.uid() = follower_id);

CREATE POLICY "Todos podem ver likes de posts" ON likes FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem dar e remover like de posts" ON likes FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Todos podem ver comentários" ON comments FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem criar e apagar os seus comentários" ON comments FOR ALL USING (auth.uid() = user_id);

-- Novas políticas para likes de comentários
CREATE POLICY "Todos podem ver likes de comentários" ON comment_likes FOR SELECT USING (true);
CREATE POLICY "Utilizadores podem dar e remover like de comentários" ON comment_likes FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Utilizadores podem ver as suas notificações" ON notifications FOR SELECT USING (auth.uid() = receiver_id);
CREATE POLICY "Utilizadores podem marcar as suas notificações como lidas" ON notifications FOR UPDATE USING (auth.uid() = receiver_id);

CREATE POLICY "Participantes podem ver as salas de chat em que estão" ON chat_rooms FOR SELECT USING (id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid()));
CREATE POLICY "Utilizadores podem criar salas de chat" ON chat_rooms FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Participantes podem ver os membros da sala" ON chat_participants FOR SELECT USING (room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid()));
CREATE POLICY "Utilizadores podem entrar ou ser adicionados a salas" ON chat_participants FOR INSERT WITH CHECK (true);

CREATE POLICY "Participantes podem ver as mensagens" ON chat_messages FOR SELECT USING (room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid()));
CREATE POLICY "Participantes podem enviar mensagens" ON chat_messages FOR INSERT WITH CHECK (sender_id = auth.uid() AND room_id IN (SELECT room_id FROM chat_participants WHERE user_id = auth.uid()));

