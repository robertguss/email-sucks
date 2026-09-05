defmodule EmailSucksWeb.Router do
  use EmailSucksWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EmailSucksWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Inertia.Plug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EmailSucksWeb do
    pipe_through :browser

    post "/auth/google", GoogleController, :start, log: false
    get "/auth/google/callback", GoogleController, :callback, log: false
    post "/auth/logout", GoogleController, :logout, log: false
    post "/gmail/disconnect", GoogleController, :disconnect, log: false
    post "/gmail/check", GoogleController, :check, log: false
    post "/gmail/controlled/:action", GoogleController, :controlled, log: false
    post "/gmail/batch/:action", GoogleController, :batch, log: false
    post "/gmail/filters/:action", GoogleController, :filters, log: false
    post "/gmail/arrival-filters/:action", GoogleController, :arrival_filters, log: false
    post "/gmail/history/:action", GoogleController, :history, log: false
    get "/batch", BatchViewController, :page, log: false
    get "/gmail/batch-view", BatchViewController, :show, log: false
    post "/gmail/batch-view/review", BatchViewController, :review, log: false
    get "/gmail/messages", GoogleController, :messages, log: false
    get "/", PageController, :home
    get "/phase-0/contract", PageController, :contract
  end

  scope "/health", EmailSucksWeb do
    pipe_through :api
    get "/ready", HealthController, :ready
  end

  # Other scopes may use custom stacks.
  # scope "/api", EmailSucksWeb do
  #   pipe_through :api
  # end
end
