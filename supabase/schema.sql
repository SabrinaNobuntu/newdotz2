-- 1. ENUMS (Tipos Personalizados)
CREATE TYPE
IF
  NOT EXISTS public.app_role AS ENUM ('admin', 'user');
  CREATE TYPE
  IF
    NOT EXISTS public.request_status AS ENUM ('pending', 'approved', 'rejected');
    CREATE TYPE
    IF
      NOT EXISTS public.referral_status AS ENUM ('pending', 'completed');
      CREATE TYPE
      IF
        NOT EXISTS public.transaction_type AS ENUM ('earned', 'spent', 'referral', 'bonus');
        CREATE TYPE
        IF
          NOT EXISTS public.material_type AS ENUM ('avaliacao', 'leitura', 'manual', 'atendimento');
          CREATE TYPE
          IF
            NOT EXISTS public.question_type AS ENUM ('rating', 'text');

            -- 2. TABELAS

            -- Tabela de perfis (vinculada ao auth.users)
            CREATE TABLE
            IF
              NOT EXISTS public.profiles (
                id UUID PRIMARY KEY REFERENCES auth.users(id)
                ON DELETE CASCADE
                , email TEXT UNIQUE NOT NULL
                , name TEXT
                , points INTEGER NOT NULL DEFAULT 0
                , surveys_completed INTEGER NOT NULL DEFAULT 0
                , referrals_count INTEGER NOT NULL DEFAULT 0
                , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                , updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
              );
              ALTER TABLE public.profiles
              ENABLE ROW LEVEL
              SECURITY;

              -- Tabela de papéis de usuário
              CREATE TABLE
              IF
                NOT EXISTS public.user_roles (
                  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
                  , user_id UUID NOT NULL REFERENCES auth.users(id)
                  ON DELETE CASCADE
                  , role app_role NOT NULL
                  , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                  , UNIQUE(user_id, role)
                );
                ALTER TABLE public.user_roles
                ENABLE ROW LEVEL
                SECURITY;

                -- Tabela de perguntas/tarefas
                CREATE TABLE
                IF
                  NOT EXISTS public.questions (
                    id SERIAL PRIMARY KEY
                    , text TEXT NOT NULL
                    , type question_type NOT NULL
                    , points INTEGER NOT NULL DEFAULT 100
                    , is_active BOOLEAN NOT NULL DEFAULT true
                    , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                    , updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                  );
                  -- Adicionando RLS que faltava
                  ALTER TABLE public.questions
                  ENABLE ROW LEVEL
                  SECURITY;

                  -- Tabela de recompensas
                  CREATE TABLE
                  IF
                    NOT EXISTS public.rewards (
                      id SERIAL PRIMARY KEY
                      , title TEXT NOT NULL
                      , description TEXT
                      , points INTEGER NOT NULL
                      , category TEXT NOT NULL
                      , is_active BOOLEAN NOT NULL DEFAULT true
                      , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                      , updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                    );
                    -- Adicionando RLS que faltava
                    ALTER TABLE public.rewards
                    ENABLE ROW LEVEL
                    SECURITY;

                    -- Tabela de materiais
                    CREATE TABLE
                    IF
                      NOT EXISTS public.materials (
                        id SERIAL PRIMARY KEY
                        , title TEXT NOT NULL
                        , description TEXT
                        , type material_type NOT NULL
                        , file_url TEXT
                        , content TEXT
                        , is_active BOOLEAN NOT NULL DEFAULT true
                        , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                        , updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                      );
                      -- Adicionando RLS que faltava
                      ALTER TABLE public.materials
                      ENABLE ROW LEVEL
                      SECURITY;

                      -- Tabela de respostas de pesquisa
                      CREATE TABLE
                      IF
                        NOT EXISTS public.survey_responses (
                          id UUID PRIMARY KEY DEFAULT gen_random_uuid()
                          , user_id UUID NOT NULL REFERENCES auth.users(id)
                          ON DELETE CASCADE
                          , question_id INTEGER NOT NULL REFERENCES questions(id)
                          ON DELETE CASCADE
                          , answer TEXT
                          , rating INTEGER CHECK (
                            rating >= 1
                            AND rating <= 5
                          )
                          , points_earned INTEGER NOT NULL DEFAULT 0
                          , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                        );
                        ALTER TABLE public.survey_responses
                        ENABLE ROW LEVEL
                        SECURITY;

                        -- Tabela de solicitações de recompensa
                        CREATE TABLE
                        IF
                          NOT EXISTS public.reward_requests (
                            id UUID PRIMARY KEY DEFAULT gen_random_uuid()
                            , user_id UUID NOT NULL REFERENCES auth.users(id)
                            ON DELETE CASCADE
                            , reward_id INTEGER NOT NULL REFERENCES rewards(id)
                            ON DELETE CASCADE
                            , status request_status NOT NULL DEFAULT 'pending'
                            , requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                            , processed_at TIMESTAMP WITH TIME ZONE
                            , processed_by UUID REFERENCES auth.users(id)
                            ON DELETE SET NULL
                          );
                          ALTER TABLE public.reward_requests
                          ENABLE ROW LEVEL
                          SECURITY;

                          -- Tabela de referências
                          CREATE TABLE
                          IF
                            NOT EXISTS public.referrals (
                              id UUID PRIMARY KEY DEFAULT gen_random_uuid()
                              , referrer_id UUID NOT NULL REFERENCES auth.users(id)
                              ON DELETE CASCADE
                              , referred_email TEXT NOT NULL
                              , referred_user_id UUID REFERENCES auth.users(id)
                              ON DELETE SET NULL
                              , points_earned INTEGER NOT NULL DEFAULT 50
                              , status referral_status NOT NULL DEFAULT 'pending'
                              , created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                              , completed_at TIMESTAMP WITH TIME ZONE
                            );
                            ALTER TABLE public.referrals
                            ENABLE ROW LEVEL
                            SECURITY;

                            -- Tabela de transações de pontos (Tabela central)
                            CREATE TABLE
                            IF
                              NOT EXISTS public.point_transactions (
                                id UUID PRIMARY KEY DEFAULT gen_random_uuid()
                                , user_id UUID NOT NULL REFERENCES auth.users(id)
                                ON DELETE CASCADE
                                , points INTEGER NOT NULL
                                , type transaction_type NOT NULL
                                , description TEXT
                                , reference_id UUID
                                , -- pode referenciar survey_responses, reward_requests, etc.
                                  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
                              );
                              ALTER TABLE public.point_transactions
                              ENABLE ROW LEVEL
                              SECURITY;

                              -- 3. FUNÇÕES E GATILHOS (TRIGGERS)

                              -- Função para verificar se usuário tem papel específico
                              CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
                              RETURNS boolean
                              LANGUAGE sql STABLE
                              SECURITY DEFINER
                              SET search_path = public AS $ $
                              SELECT
                                EXISTS (
                                  SELECT
                                    1
                                  FROM
                                    public.user_roles
                                  WHERE
                                    user_id = _user_id
                                    AND role = _role
                                ) $ $;

                              -- Função para criar perfil e role 'user' automaticamente
                              CREATE OR REPLACE FUNCTION public.handle_new_user()
                              RETURNS TRIGGER
                              LANGUAGE plpgsql
                              SECURITY DEFINER
                              SET search_path = public AS $ $
                              BEGIN
                                INSERT INTO
                                  public.profiles (id, email, name)
                                VALUES
                                  (
                                    new.id
                                    , new.email
                                    , COALESCE(
                                      new.raw_user_meta_data - > > 'name'
                                      , split_part(
                                        new.email
                                        , '@'
                                        , 1
                                      )
                                    )
                                  );

                                -- Adicionar papel padrão de 'user'
                                INSERT INTO
                                  public.user_roles (user_id, role)
                                VALUES
                                  (
                                    new.id
                                    , 'user'
                                  );

                                RETURN
                                new;
                              END;
                              $ $;

                              -- Trigger para criar perfil no registro
                              CREATE TRIGGER on_auth_user_created
                              AFTER INSERT
                              ON auth.users
                              FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

                              -- Função para atribuir automaticamente role admin para admin@sistema.com
                              CREATE OR REPLACE FUNCTION public.handle_admin_user()
                              RETURNS TRIGGER
                              LANGUAGE plpgsql
                              SECURITY DEFINER
                              SET search_path = public AS $ $
                              BEGIN
                                -- Se o email for admin@sistema.com, atribui role de admin
                                IF
                                  NEW.email = 'admin@sistema.com'
                                THEN
                                  INSERT INTO
                                    public.user_roles (user_id, role)
                                  VALUES
                                    (
                                      NEW.id
                                      , 'admin'
                                    )
                                  ON CONFLICT (user_id, role)
                                DO
                                  NOTHING;
                                END IF;
                                RETURN
                                NEW;
                              END;
                              $ $;

                              -- Trigger para verificar e atribuir role admin automaticamente
                              CREATE TRIGGER on_auth_admin_check
                              AFTER INSERT
                              ON auth.users
                              FOR EACH ROW EXECUTE FUNCTION public.handle_admin_user();

                              -- Função para atualizar `updated_at`
                              CREATE OR REPLACE FUNCTION update_updated_at_column()
                              RETURNS TRIGGER AS $ $
                              BEGIN
                                NEW.updated_at = NOW();
                                RETURN
                                NEW;
                              END;
                              $ $
                              language 'plpgsql';

                              -- Triggers para `updated_at`
                              CREATE TRIGGER update_profiles_updated_at
                              BEFORE UPDATE
                              ON profiles
                              FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
                              CREATE TRIGGER update_questions_updated_at
                              BEFORE UPDATE
                              ON questions
                              FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
                              CREATE TRIGGER update_rewards_updated_at
                              BEFORE UPDATE
                              ON rewards
                              FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
                              CREATE TRIGGER update_materials_updated_at
                              BEFORE UPDATE
                              ON materials
                              FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

                              -- --- INÍCIO DA LÓGICA DE PONTOS AUTOMATIZADA ---

                              -- 1. Função que atualiza o total de pontos em `profiles`
                              --    (Esta é a versão correta, removendo a duplicada)
                              CREATE OR REPLACE FUNCTION public.update_profile_points()
                              RETURNS TRIGGER AS $ $
                              BEGIN
                                IF TG_OP = 'INSERT' THEN
                                  -- Adiciona ou subtrai pontos do perfil
                                  UPDATE
                                    public.profiles
                                  SET points = points + NEW.points
                                  WHERE
                                    id = NEW.user_id;
                                  RETURN
                                  NEW;
                                  ELSIF TG_OP = 'DELETE'
                                THEN
                                  -- Reverte a transação (caso um admin delete um registro de transação)
                                  UPDATE
                                    public.profiles
                                  SET points = points - OLD.points
                                  WHERE
                                    id = OLD.user_id;
                                  RETURN
                                  OLD;
                                END IF;
                                RETURN NULL;
                              END;
                              $ $
                              language 'plpgsql';

                              -- 2. Gatilhos que INSEREM na `point_transactions` (NOVO)

                              -- Gatilho para quando uma pesquisa é respondida
                              CREATE OR REPLACE FUNCTION public.fn_log_survey_points()
                              RETURNS TRIGGER AS $ $
                              BEGIN
                                -- Insere uma transação de 'earned' quando uma resposta é criada
                                INSERT INTO
                                  public.point_transactions (user_id, points, type, description, reference_id)
                                VALUES
                                  (
                                    NEW.user_id
                                    , NEW.points_earned
                                    , 'earned'
                                    , 'Pesquisa respondida'
                                    , NEW.id
                                  );

                                -- Atualiza o contador de pesquisas no perfil
                                UPDATE
                                  public.profiles
                                SET surveys_completed = surveys_completed + 1
                                WHERE
                                  id = NEW.user_id;

                                RETURN
                                NEW;
                              END;
                              $ $
                              language 'plpgsql';

                              -- Gatilho para quando um prêmio é solicitado (pontos negativos)
                              CREATE OR REPLACE FUNCTION public.fn_log_reward_spend()
                              RETURNS TRIGGER AS $ $
                              DECLARE reward_points INTEGER;
                              BEGIN
                                -- Busca os pontos da recompensa solicitada
                                SELECT
                                  points
                                INTO
                                  reward_points
                                FROM
                                  public.rewards
                                WHERE
                                  id = NEW.reward_id;

                                -- Insere a transação com pontos negativos
                                INSERT INTO
                                  public.point_transactions (user_id, points, type, description, reference_id)
                                VALUES
                                  (
                                    NEW.user_id
                                    , - reward_points
                                    , 'spent'
                                    , 'Resgate de recompensa'
                                    , NEW.id
                                  );
                                RETURN
                                NEW;
                              END;
                              $ $
                              language 'plpgsql';

                              -- Gatilho para quando uma indicação é completada
                              CREATE OR REPLACE FUNCTION public.fn_log_referral_points()
                              RETURNS TRIGGER AS $ $
                              BEGIN
                                -- Só insere a transação se o status mudou para 'completed'
                                IF
                                  OLD.status = 'pending'
                                  AND
                                  NEW.status = 'completed'
                                THEN
                                  INSERT INTO
                                    public.point_transactions (user_id, points, type, description, reference_id)
                                  VALUES
                                    (
                                      NEW.referrer_id
                                      , NEW.points_earned
                                      , 'referral'
                                      , 'Indicação completada'
                                      , NEW.id
                                    );

                                  -- Atualiza o contador de indicações no perfil
                                  UPDATE
                                    public.profiles
                                  SET referrals_count = referrals_count + 1
                                  WHERE
                                    id = NEW.referrer_id;
                                END IF;
                                RETURN
                                NEW;
                              END;
                              $ $
                              language 'plpgsql';


                              -- 3. Ativando os Gatilhos

                              -- Este gatilho assiste `point_transactions` e atualiza o total em `profiles`
                              CREATE TRIGGER update_points_on_transaction
                              AFTER INSERT
                              OR DELETE
                              ON public.point_transactions
                              FOR EACH ROW EXECUTE FUNCTION public.update_profile_points();

                              -- Este gatilho assiste `survey_responses` e cria uma transação (NOVO)
                              CREATE TRIGGER log_survey_points
                              AFTER INSERT
                              ON public.survey_responses
                              FOR EACH ROW EXECUTE FUNCTION public.fn_log_survey_points();

                              -- Este gatilho assiste `reward_requests` e cria uma transação (NOVO)
                              CREATE TRIGGER log_reward_spend
                              AFTER INSERT
                              ON public.reward_requests
                              FOR EACH ROW EXECUTE FUNCTION public.fn_log_reward_spend();

                              -- Este gatilho assiste `referrals` e cria uma transação (NOVO)
                              CREATE TRIGGER log_referral_points
                              AFTER UPDATE
                              ON public.referrals
                              FOR EACH ROW EXECUTE FUNCTION public.fn_log_referral_points();

                              -- --- FIM DA LÓGICA DE PONTOS AUTOMATIZADA ---


                              -- 4. POLÍTICAS RLS (Row Level Security)

                              -- profiles
                              CREATE POLICY "Users can view own profile"
                              ON profiles
                              FOR
                              SELECT
                              USING (auth.uid() = id);
                              CREATE POLICY "Users can update own profile"
                              ON profiles
                              FOR UPDATE
                              USING (auth.uid() = id);
                              CREATE POLICY "Admins can view all profiles"
                              ON profiles
                              FOR
                              SELECT
                              USING (public.has_role(auth.uid(), 'admin'));
                              CREATE POLICY "Admins can update all profiles"
                              ON profiles
                              FOR UPDATE
                              USING (public.has_role(auth.uid(), 'admin'));

                              -- user_roles
                              CREATE POLICY "Users can view own roles"
                              ON user_roles
                              FOR
                              SELECT
                              USING (auth.uid() = user_id);
                              CREATE POLICY "Admins can manage all roles"
                              ON user_roles
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));

                              -- questions (Políticas adicionadas)
                              CREATE POLICY "Admins can manage questions"
                              ON questions
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));
                              CREATE POLICY "Authenticated users can view active questions"
                              ON questions
                              FOR
                              SELECT
                              USING (
                                auth.role() = 'authenticated'
                                AND is_active = true
                              );

                              -- rewards (Políticas adicionadas)
                              CREATE POLICY "Admins can manage rewards"
                              ON rewards
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));
                              CREATE POLICY "Authenticated users can view active rewards"
                              ON rewards
                              FOR
                              SELECT
                              USING (
                                auth.role() = 'authenticated'
                                AND is_active = true
                              );

                              -- materials (Políticas adicionadas)
                              CREATE POLICY "Admins can manage materials"
                              ON materials
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));
                              CREATE POLICY "Authenticated users can view active materials"
                              ON materials
                              FOR
                              SELECT
                              USING (
                                auth.role() = 'authenticated'
                                AND is_active = true
                              );

                              -- survey_responses
                              CREATE POLICY "Users can view own responses"
                              ON survey_responses
                              FOR
                              SELECT
                              USING (auth.uid() = user_id);
                              CREATE POLICY "Users can insert own responses"
                              ON survey_responses
                              FOR INSERT
                              WITH CHECK (auth.uid() = user_id);
                              CREATE POLICY "Admins can view all responses"
                              ON survey_responses
                              FOR
                              SELECT
                              USING (public.has_role(auth.uid(), 'admin'));

                              -- reward_requests
                              CREATE POLICY "Users can view own requests"
                              ON reward_requests
                              FOR
                              SELECT
                              USING (auth.uid() = user_id);
                              CREATE POLICY "Users can create requests"
                              ON reward_requests
                              FOR INSERT
                              WITH CHECK (auth.uid() = user_id);
                              CREATE POLICY "Admins can manage all requests"
                              ON reward_requests
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));

                              -- referrals
                              CREATE POLICY "Users can view own referrals"
                              ON referrals
                              FOR
                              SELECT
                              USING (auth.uid() = referrer_id);
                              CREATE POLICY "Users can create referrals"
                              ON referrals
                              FOR INSERT
                              WITH CHECK (auth.uid() = referrer_id);
                              CREATE POLICY "Admins can manage all referrals"
                              ON referrals
                              FOR ALL
                              USING (public.has_role(auth.uid(), 'admin'));

                              -- point_transactions
                              CREATE POLICY "Users can view own transactions"
                              ON point_transactions
                              FOR
                              SELECT
                              USING (auth.uid() = user_id);
                              CREATE POLICY "Admins can view all transactions"
                              ON point_transactions
                              FOR
                              SELECT
                              USING (public.has_role(auth.uid(), 'admin'));
                              -- (Não há política de INSERT para transações, pois elas são gerenciadas apenas por Triggers)


                              -- 5. DADOS INICIAIS
                              INSERT INTO
                                questions (text, type, points)
                              VALUES
                                (
                                  'Como você avalia o ambiente de trabalho?'
                                  , 'rating'
                                  , 100
                                )
                                , ('O que podemos melhorar na empresa?', 'text', 150)
                                , ('Você recomendaria nossa empresa?', 'rating', 100)
                                , (
                                  'Qual sua satisfação com a liderança?'
                                  , 'rating'
                                  , 100
                                )
                                , ('Descreva sua experiência na empresa', 'text', 200)
                              ON CONFLICT (id)
                            DO
                              NOTHING;

                              INSERT INTO
                                rewards (title, description, points, category)
                              VALUES
                                (
                                  'Vale Combustível R$ 50'
                                  , 'Crédito para combustível no valor de R$ 50'
                                  , 500
                                  , 'Transporte'
                                )
                                , (
                                  'Almoço Grátis'
                                  , 'Refeição gratuita no restaurante da empresa'
                                  , 200
                                  , 'Alimentação'
                                )
                                , (
                                  'Dia de Folga Extra'
                                  , 'Um dia adicional de descanso'
                                  , 1000
                                  , 'Tempo Livre'
                                )
                                , (
                                  'Kit Produtos da Empresa'
                                  , 'Produtos promocionais da empresa'
                                  , 300
                                  , 'Brindes'
                                )
                                , (
                                  'Curso Online'
                                  , 'Acesso a curso de capacitação profissional'
                                  , 800
                                  , 'Educação'
                                )
                                , (
                                  'Vale Presente R$ 100'
                                  , 'Vale presente para uso em lojas parceiras'
                                  , 800
                                  , 'Compras'
                                )
                              ON CONFLICT (id)
                            DO
                              NOTHING;

                              INSERT INTO
                                materials (title, description, type, content)
                              VALUES
                                (
                                  'Manual de Integração'
                                  , 'Guia completo para novos funcionários'
                                  , 'manual'
                                  , 'Conteúdo do manual de integração...'
                                )
                                , (
                                  'Política de Qualidade'
                                  , 'Documento sobre padrões de qualidade'
                                  , 'leitura'
                                  , 'Política de qualidade da empresa...'
                                )
                                , (
                                  'Avaliação de Desempenho'
                                  , 'Formulário de avaliação trimestral'
                                  , 'avaliacao'
                                  , 'Critérios de avaliação...'
                                )
                                , (
                                  'Protocolo de Atendimento'
                                  , 'Procedimentos para atendimento ao cliente'
                                  , 'atendimento'
                                  , 'Protocolo de atendimento...'
                                )
                              ON CONFLICT (id)
                            DO
                              NOTHING;