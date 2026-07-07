---
name: light-review-DUnitX
description: Reference for structuring Delphi DUnitX unit tests — test project layout, [TestFixture]/[Setup]/[TearDown]/[Test], Method_Scenario_Expected naming, the assertion cheat-sheet, substituting collaborators with a concrete fake (shared base, no interface required), and SQLite :memory: integration tests. Load this when writing, organising or reviewing DUnitX tests. Adapted to Gabriel's rules — no fake/zero-assert tests, no form/UI tests, compile ONLY via the light-compiler agent, then launch the EXE yourself. Pairs with /light-review-RedGreen and /light-review-FakeTest.
---

# DUnitX testing — reference

For the red-green discipline (failing test first, confirmed red on its assertion) use `/light-review-RedGreen`. This skill is the structural reference: how a fixture, a fake and an integration test are shaped here.

## Non-negotiables (Gabriel's rules)

- **Every `[Test]` makes a real assertion.** Keep `FailsOnNoAsserts` on in the runner; a zero-assertion or `Assert.Pass`-only test is a fake test — the exact thing `/light-review-FakeTest` hunts.
- **No form / UI tests.** Restrict DUnitX to domain and service logic. Layout lives in the `.dfm`/`.fmx` and is not unit-tested.
- **Compile only via the `light-compiler` agent** (global `CLAUDE.md` rule); the agent reports compile results only — **launching the test EXE to read pass/fail counts is your job.**
- **Reuse LightSaber** in the code under test before hand-rolling.
- Test project is usually `UnitTesting\Tests.dproj`; if none exists, do not guess a layout — ask (template: `c:\AI\Claude Code\TEMPLATE FOLDER\UnitTesting (TEMPLATE)\`).

## Fixture skeleton

```pascal
type
  [TestFixture]
  TCustomerServiceTest = class
  private
    FService: TCustomerService;
    FRepo: TMemoryCustomerRepository;   // concrete fake, see below
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;
    [Test]     procedure Create_WithValidData_Succeeds;
    [Test]     procedure Create_WithEmptyName_RaisesValidation;
  end;

procedure TCustomerServiceTest.Setup;
begin
  FRepo := TMemoryCustomerRepository.Create;
  FService := TCustomerService.Create(FRepo);
end;

procedure TCustomerServiceTest.TearDown;
begin
  FService.Free;
  FRepo.Free;
end;
```

Register the fixture: `initialization TDUnitX.RegisterTestFixture(TCustomerServiceTest);`

## Naming: Method_Scenario_ExpectedBehavior

| Name | Reads as |
|---|---|
| `Create_WithValidData_Succeeds` | happy path |
| `Create_WithEmptyName_RaisesValidation` | validation |
| `GetById_UnknownId_RaisesNotFound` | not found |
| `Delete_WhenReferenced_RaisesBusinessRule` | business rule |

## Assertion cheat-sheet

```pascal
Assert.AreEqual(Expected, Actual);
Assert.IsTrue(Cond);  Assert.IsFalse(Cond);
Assert.IsNotNull(Obj);  Assert.IsNull(Obj);
Assert.WillRaise(procedure begin FService.DoBad; end, EValidationException);
Assert.WillNotRaiseAny(procedure begin FService.DoGood; end);
Assert.AreEqual(3, LList.Count);
```

## Faking a collaborator — no interface required

The spec-kit fakes everything through an interface. Gabriel avoids interfaces (the IDE cannot list implementers). Prefer a **shared base class with virtual methods**: the real collaborator and the in-memory fake both descend from it, and the SUT holds the base type.

```pascal
type
  TCustomerRepository = class            // base: the seam
    function FindById(AId: Integer): TCustomer; virtual; abstract;
    procedure Insert(ACustomer: TCustomer); virtual; abstract;
  end;

  TMemoryCustomerRepository = class(TCustomerRepository)  // fake, test-only
    // backed by a TObjectList<TCustomer>, no DB
  end;
```

Only implement a fake through an interface when the production seam is **already** an interface — never introduce one just to test.

## Integration test — SQLite :memory:

Exercise the real repository against a throwaway in-memory database; no fake, no disk:

```pascal
procedure TRepoIntegrationTest.Setup;
begin
  FConn := TFDConnection.Create(nil);
  FConn.DriverName := 'SQLite';
  FConn.Params.Database := ':memory:';
  FConn.Connected := True;
  FConn.ExecSQL('CREATE TABLE customers (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
  FRepo := TFireDACCustomerRepository.Create(FConn);
end;

procedure TRepoIntegrationTest.TearDown;
begin
  FRepo.Free;
  FConn.Free;   // drops the in-memory db
end;
```

## Checklist

- [ ] Name follows `Method_Scenario_Expected`.
- [ ] Exactly one behaviour asserted per test; at least one real `Assert.*`.
- [ ] `Setup`/`TearDown` free non-ARC objects; no leaks, no side effects between tests.
- [ ] Collaborators faked via shared base (or an already-existing interface), not a new interface.
- [ ] Both happy and error scenarios covered.
- [ ] Built via the light-compiler agent; EXE launched and counts read.
