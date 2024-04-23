import { useState, useContext } from "react";
import { LoginContext } from "../context/LoginContext";
import { Bars3Icon } from "@heroicons/react/24/solid";
import { PrimaryButton } from "./Buttons";
import {
  handleLogin,
  handleLogout,
} from "../providers/InternetIdentityProvider";

const Navbar = () => {
  const [showMenu, setShowMenu] = useState(false);

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

  const LogInOrOutButton = () => {
    const { loginInfo, updateLoginInfo } = useContext(LoginContext);

    return (
      <>
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
      </>
    );
  };

  const MenuBurgerButton = () => {
    return (
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
    );
  };

  const MenuItems = () => {
    const Item = ({ text }) => {
      return (
        <li>
          <a
            href="#"
            className="block rounded px-3 py-4 text-center text-gray-900 hover:text-primary md:p-0"
          >
            {text}
          </a>
        </li>
      );
    };

    return (
      <ul className="mt-4 flex flex-col rounded-lg bg-gray-100 p-4 font-medium md:mt-0 md:flex-row md:space-x-8 md:border-0 md:bg-white md:p-0">
        <Item text="About"></Item>
        <Item text="Contact"></Item>
      </ul>
    );
  };

  return (
    <nav className="border-b-2 border-b-secondary">
      <div className="flex flex-wrap justify-between p-4">
        <Logo></Logo>
        <div className="flex space-x-3 md:order-2 md:space-x-0">
          <LogInOrOutButton></LogInOrOutButton>
          <MenuBurgerButton></MenuBurgerButton>
        </div>

        <div
          id="navbar-cta"
          className={`${showMenu ? "" : "hidden"} w-full items-center justify-between md:order-1 md:flex md:w-auto md:grow md:justify-end md:pr-8`}
        >
          <MenuItems></MenuItems>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
