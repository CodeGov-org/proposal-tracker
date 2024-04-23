import { useState, useEffect } from "react";
import { LoginContext } from "./context/LoginContext";
import { proposal_tracker_backend } from "declarations/proposal_tracker_backend";
import Feeds from "./pages/Feeds";
import AdminDashboard from "./pages/AdminDashboard";
import { checkAndRecoverLogin } from "./providers/InternetIdentityProvider";

function App() {
  const [route, setRoute] = useState("feeds"); // "feed" -> "login" -> "admin" -> "feed-edit"
  const [loginInfo, setLoginInfo] = useState({});
  // eslint-disable-next-line no-unused-vars
  const [backendActor, setBackendActor] = useState(proposal_tracker_backend);

  const updateLoginInfo = (loggedWith, principal, backendActor) => {
    // handle logout
    if (loggedWith === "") {
      setLoginInfo({});
      setBackendActor(proposal_tracker_backend);
      setRoute("feeds");
      return;
    }

    // handle login
    setLoginInfo({ loggedWith, principal });
    setBackendActor(backendActor);
    setRoute("adminDashboard");
  };

  useEffect(() => {
    if (!process.env.VITEST) checkAndRecoverLogin(updateLoginInfo);
  }, []);

  return (
    <LoginContext.Provider value={{ loginInfo, updateLoginInfo }}>
      {route === "feeds" && <Feeds></Feeds>}
      {route === "adminDashboard" && <AdminDashboard></AdminDashboard>}
    </LoginContext.Provider>
  );
}

export default App;
