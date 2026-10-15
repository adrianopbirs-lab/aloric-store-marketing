# Aloric Store — plataforma de marketing v2

Esta é uma base full-stack para implantar a plataforma de marketing da Aloric Store. Usa Next.js, Supabase Auth e PostgreSQL com Row Level Security (RLS). O sistema não envia mensagens reais: as campanhas são gravadas como rascunhos e os canais aparecem desativados até serem configurados e testados.

## O que está implementado
- Aplicação web responsiva em português.
- Login administrativo por e-mail/senha via Supabase Auth; sem cadastro público no site.
- Sessão gerida por cookies seguros via `@supabase/ssr` e verificação do usuário no servidor.
- Banco persistente para contatos, produtos, campanhas, eventos e lista de supressão.
- Políticas RLS com isolamento por `owner_id`.
- Cadastro de contato com validação, origem, interesses, autorização por canal e evidência do consentimento.
- Cadastro de campanhas como rascunho, sem endpoint de disparo.
- API autenticada para listar/criar contatos e campanhas.
- Nenhuma chave secreta incluída no código.

## Requisitos
- Node.js 20.9+ recomendado.
- Conta Supabase.
- Conta Vercel para hospedagem (plano gratuito pode servir para começar, sujeito aos limites/termos vigentes).
- Domínio próprio já registrado.

## 1. Configurar o banco e autenticação
1. Crie um projeto no Supabase.
2. Abra SQL Editor e execute `supabase/schema.sql`.
3. Em Project Settings > API, copie a Project URL e a chave publicável/anon para variáveis `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY`.
4. Em Authentication, desative signups públicos e confirme os URLs de redirecionamento do seu ambiente.
5. Crie o único usuário administrador manualmente em Authentication > Users (ou pelo fluxo administrativo suportado pelo Supabase). Use uma senha forte e MFA se disponível.
6. Não coloque a `service_role` key no navegador ou em qualquer variável `NEXT_PUBLIC_*`.

## 2. Rodar localmente
```bash
cp .env.example .env.local
# Edite .env.local com os valores do seu projeto Supabase
npm install
npm run dev
```
Abra `http://localhost:3000`. A raiz redireciona para `/dashboard`; sem sessão, vai para `/login`.

## 3. Publicar na Vercel
1. Suba esta pasta para um repositório Git privado.
2. Importe o repositório em Vercel.
3. Configure as duas variáveis públicas do Supabase nas Environment Variables da Vercel.
4. Faça o deploy e teste login, criação de contato e criação de rascunho.
5. Em Vercel > Domains, adicione seu domínio e siga os registros DNS exibidos pela Vercel. Não altere DNS até identificar onde o domínio é gerenciado e preservar os registros de e-mail existentes.
6. Atualize os Site URL/Redirect URLs no Supabase para o domínio publicado.

## 4. Integrações (ainda não ativadas)
- E-mail: conectar Resend ou Brevo, validar domínio remetente (SPF/DKIM/DMARC) e implementar descadastro/webhooks.
- WhatsApp: abrir/configurar Meta Business Portfolio, WABA e número dedicado; verificar o negócio/número quando solicitado, criar modelos de mensagem e obter token com permissões mínimas. O disparo deve ser implementado apenas no servidor, com templates e opt-out.
- IA: configurar fornecedor, chave exclusivamente no servidor, limites de gasto e geração de rascunhos.
- Amazon/Mercado Livre: só integrar por APIs oficiais, com OAuth/permissões e escopo definido. O painel atual não importa pedidos nem publica anúncios.

## Controles de segurança importantes
- Nunca publicar `service_role`, tokens do WhatsApp, chave de e-mail ou chave de IA no browser/repositório.
- Manter signups públicos desativados; criar apenas o administrador autorizado.
- RLS é obrigatória; execute e revise `supabase/schema.sql` no projeto certo.
- Antes de disparos: consentimento demonstrável por canal, lista de supressão, deduplicação, rate limit, idempotência, logs, descadastro funcional, revisão humana e campanha de teste.
- Não raspar e-mails ou telefones de perfis sociais para marketing. Captar por formulários/Lead Ads autorizados, checkout e opt-in claro, respeitando LGPD e regras das plataformas.
- A aplicação não foi auditada por pentest nem submetida a avaliação jurídica; testar e revisar antes de dados reais em produção.

## Estado atual
Base de código preparada, não implantada em conta externa. Banco, domínio, e-mail, IA e WhatsApp não estão conectados por este pacote. Nenhuma mensagem foi enviada. O deploy exige que o proprietário configure as contas e credenciais nas respectivas plataformas.
