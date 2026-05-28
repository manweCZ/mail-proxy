# Run with: mix run priv/repo/seeds.exs

alias MailProxy.Accounts.Account
alias MailProxy.Repo

Repo.insert!(%Account{
  name: "Test Account",
  bearer_token: "test-token-changeme",
  smtp_host: "smtp.example.com",
  smtp_port: 587,
  smtp_user: "user@example.com",
  smtp_password: "secret",
  rate_limit_per_second: "0.5",
  webhook_url: nil
})

IO.puts("Seeded 1 test account (bearer_token: test-token-changeme)")
