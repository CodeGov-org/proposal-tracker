import { test; suite; expect } "mo:test/async";
import Main "../src/proposal_tracker_backend/main";

let mainActor = await Main.ProposalTrackerBackend();

// await suite(
//     "#greet",
//     func() : async () {
//         await test(
//             "it greets you",
//             func() : async () {
//                 let result = await mainActor.greet("Alice");
//                 expect.text(result).equal("Hello, Alice!");
//             },
//         );
//     },
// );
