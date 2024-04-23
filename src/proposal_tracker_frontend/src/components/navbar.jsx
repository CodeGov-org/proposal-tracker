import { useState, useContext } from "react";
import { LoginContext } from "../context/LoginContext";
import { Bars3Icon } from "@heroicons/react/24/solid";
import { PrimaryButton } from "./Buttons";
import {
  handleLogin,
  handleLogout,
} from "../providers/InternetIdentityProvider";

const Logo = () => {
  return (
    <a href="/" className="flex items-center space-x-3">
      <img src="/codegov-logo.png" className="h-10" alt="Codegov Logo" />
      <span className="whitespace-nowrap text-2xl font-semibold">
        Proposal Tracker
      </span>
    </a>
  );
};

const Navbar = () => {
  const [showMenu, setShowMenu] = useState(false);
  const { loginInfo, updateLoginInfo } = useContext(LoginContext);

  return (
    <nav className="border-b-2 border-b-secondary">
      <div className="mx-auto flex flex-wrap items-center justify-between p-4">
        <Logo></Logo>
        <div className="flex space-x-3 md:order-2 md:space-x-0">
          {loginInfo.principal ? (
            <PrimaryButton
              text="Logout"
              onClick={() => handleLogout(updateLoginInfo)}
            ></PrimaryButton>
          ) : (
            <PrimaryButton
              text="Login"
              onClick={() => handleLogin(updateLoginInfo)}
            ></PrimaryButton>
          )}
          <button
            id="menu"
            data-collapse-toggle="navbar-cta"
            type="button"
            className="inline-flex h-10 w-10 items-center justify-center rounded-lg p-2 text-sm text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 md:hidden"
            aria-controls="navbar-cta"
            aria-expanded="false"
            onClick={() => {
              setShowMenu(!showMenu);
            }}
          >
            <span className="sr-only">Open main menu</span>
            <Bars3Icon></Bars3Icon>
          </button>
        </div>

        <div
          className={`${showMenu ? "" : "hidden"} w-full items-center justify-between md:order-1 md:flex md:w-auto`}
          id="navbar-cta"
        >
          <ul className="mt-4 flex flex-col rounded-lg border border-gray-100 bg-gray-50 p-4 font-medium md:mt-0 md:flex-row md:space-x-8 md:border-0 md:bg-white md:p-0">
            <li>
              <a
                href="#"
                className="block rounded px-3 py-2 text-gray-900 hover:bg-gray-100 md:p-0 md:hover:bg-transparent md:hover:text-blue-700"
              >
                About
              </a>
            </li>
            <li>
              <a
                href="#"
                className="block rounded px-3 py-2 text-gray-900 hover:bg-gray-100 md:p-0 md:hover:bg-transparent md:hover:text-blue-700"
              >
                Contact
              </a>
            </li>
          </ul>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
