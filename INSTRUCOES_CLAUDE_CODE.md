# Instruções para o Claude Code — leia antes de escrever qualquer linha

## Identidade do projeto

Esses projetos são de Renan Ferreira de Souza, desenvolvedor backend com experiência
em Java/Spring Boot em produção. O código deve refletir o estilo de alguém que escreveu
vários sistemas enterprise — não um tutorial nem um projeto acadêmico.

## Configuração obrigatória antes do primeiro commit

```bash
git config user.name "Renan Ferreira de Souza"
git config user.email "renanferreira102030@gmail.com"
```

Rodar isso dentro de cada repositório antes de qualquer `git commit`.
Nunca usar `--co-author`, nunca adicionar `Co-Authored-By` em mensagens.

## Regras de código

- SOLID: uma classe = uma responsabilidade
- Domínio sem anotações de framework (sem @Autowired, @Component, @Entity no model)
- Controller só faz: validar entrada, chamar port, formatar saída
- Service só faz: orquestrar domínio
- Comentários explicam o PORQUÊ, não o QUÊ
- Não comitar nada — o desenvolvedor fará os commits manualmente

## Regras de README

- Em inglês
- Primeira pessoa ("I built this...", "The interesting part was...")
- Seção obrigatória: "Known limitations" — honesto sobre o que falta
- Sem "demonstrates", "showcases", "comprehensive"
- Tom de quem escreveu pra resolver um problema real

## Antes de terminar

Rode o build e os testes. Liste o que foi criado. Não faça nenhum commit.
