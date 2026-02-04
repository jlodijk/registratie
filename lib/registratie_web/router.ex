defmodule RegistratieWeb.Router do
  use RegistratieWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RegistratieWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug RegistratieWeb.Plugs.FetchCurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug RegistratieWeb.Plugs.RequireAuthenticatedUser
  end

  # --------------------
  # Browser routes (HTML)
  # --------------------

  scope "/", RegistratieWeb do
    pipe_through [:browser]

    auth_routes(RegistratieWeb.AuthPlug, Registratie.Accounts.User)

    resources "/students", StudentController
    # Homepagina
    live "/home", HomeLive, :index

    # Login / Logout

    get "/", LoginController, :new
    get "/login", LoginController, :new
    post "/login", LoginController, :create
    get "/logout", LoginController, :logout
    delete "/logout", LoginController, :delete

    get "/password/nieuw", PasswordController, :new
    post "/password/nieuw", PasswordController, :create
    get "/password/reset", PasswordController, :reset_form
    post "/password/reset", PasswordController, :reset

    get "/attendance", AttendanceController, :index
    post "/attendance/export", AttendanceController, :export

    get "/contact", ContactController, :index
    get "/contact/bewerken", ContactController, :edit
    post "/contact", ContactController, :update

    get "/contactpersonen", ContactPersonSchoolController, :index
    post "/contactpersonen", ContactPersonSchoolController, :create
    post "/contactpersonen/:id/update", ContactPersonSchoolController, :update
    delete "/contactpersonen", ContactPersonSchoolController, :delete

    get "/studenten/overzicht", StudentOverviewController, :index
    post "/studenten/extra-uren", StudentOverviewController, :add_extra_hours
    post "/studenten/verwijder", StudentOverviewController, :delete

    live "/mijn-uren", MyHoursLive, :index

    get "/bbsids", BssidController, :index
    post "/bbsids", BssidController, :create
    get "/bbsids/:id/edit", BssidController, :edit
    post "/bbsids/:id/update", BssidController, :update
    delete "/bbsids/:id", BssidController, :delete

    get "/profiel", StudentProfileController, :edit
    post "/profiel", StudentProfileController, :update
    post "/profiel/uitschrijven", StudentProfileController, :delete

    get "/devices", DevicesController, :index
    get "/network", NetworkController, :index
    get "/taken", TaskController, :index
    post "/taken", TaskController, :create
    post "/taken/:id/status", TaskController, :update_status
    get "/hulpvragen", HelpRequestController, :index
    post "/hulpvragen", HelpRequestController, :create
    post "/hulpvragen/:id/status", HelpRequestController, :update_status
    post "/hulpvragen/:id/feedback", HelpRequestController, :feedback
    get "/hulpvragen/overzicht", HelpRequestController, :overview
    get "/standaard-taken", StandardTaskController, :index
    post "/standaard-taken", StandardTaskController, :create
    delete "/standaard-taken", StandardTaskController, :delete
    get "/laptop-inventarisatie", LaptopInventoryController, :new
    post "/laptop-inventarisatie", LaptopInventoryController, :create
    get "/network-inventarisatie", NetworkInventoryController, :new
    post "/network-inventarisatie", NetworkInventoryController, :create
    get "/progress", ProgressController, :index
    get "/missie", MissionController, :index
    post "/missie", MissionController, :create
    get "/missie/overzicht", MissionController, :overview

    # Registratiepagina
    get "/register", RegisterController, :new
    post "/register", RegisterController, :create
  end

  # Beveiligde routes

  # --------------------
  # JSON API routes
  # --------------------

  scope "/api", RegistratieWeb do
    pipe_through [:api]

    post "/login", AuthController, :login
    get "/current_user", AuthController, :current_user
  end
end
