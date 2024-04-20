import { useState } from "react";
import Feeds from "./pages/feeds";
// import { proposal_tracker_backend } from "declarations/proposal_tracker_backend";

function App() {
  // eslint-disable-next-line no-unused-vars
  const [route, setRoute] = useState("feeds"); // "feed" -> "login" -> "admin" -> "feed-edit"

  return <>{route === "feeds" && <Feeds></Feeds>}</>;
}

export default App;
