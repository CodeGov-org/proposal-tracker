import { Actor, HttpAgent } from "@dfinity/agent";
import { AuthClient } from "@dfinity/auth-client";
import { canisterId as internetIdentityId } from "declarations/internet_identity";
import {
  canisterId as backendId,
  idlFactory as backendFactory,
} from "declarations/proposal_tracker_backend";

export const handleLogin = async (updateLoginInfo) => {
  // Login with II provider
  const authClient = await AuthClient.create();

  // handle already authenticated case
  if (await authClient.isAuthenticated()) {
    await handleAuthenticated(authClient, updateLoginInfo);
  } else {
    await authClient.login({
      // 7 days in nanoseconds
      // source: https://www.npmjs.com/package/@dfinity/auth-client
      maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
      identityProvider:
        process.env.DFX_NETWORK == "local"
          ? "http://" + internetIdentityId + ".localhost:4943/"
          : "https://identity.ic0.app/",
      onSuccess: async () => {
        await handleAuthenticated(authClient, updateLoginInfo);
      },
    });
  }
};

const handleAuthenticated = async (authClient, updateLoginInfo) => {
  const identity = await authClient.getIdentity();
  const agent = new HttpAgent({ identity });

  if (process.env.DFX_NETWORK === "local") {
    agent.fetchRootKey();
  }

  const backendActor = Actor.createActor(backendFactory, {
    agent,
    canisterId: backendId,
  });

  const principal = identity.getPrincipal().toText();
  updateLoginInfo("ii", principal, backendActor);
};

export const handleLogout = async (updateLoginInfo) => {
  const authClient = await AuthClient.create();

  // only logout if still authenticated
  if (await authClient.isAuthenticated()) {
    await authClient.logout();
  }

  updateLoginInfo({});
};
