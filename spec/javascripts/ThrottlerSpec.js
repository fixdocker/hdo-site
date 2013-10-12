describe('HDO.throttler', function () {
  var callback, throttler, clock;

  beforeEach(function () {
    callback = jasmine.createSpy();
    throttler = HDO.throttler.create(100);
    jasmine.Clock.useMock();
  });

  it("should make request after minimum timeout", function () {
    throttler.queue("LOL", callback);
    jasmine.Clock.tick(100);

    expect(callback).toHaveBeenCalledWith("LOL");
  });

  it("should not make request before minimum timeout", function () {
    throttler.queue("LOL", callback);
    jasmine.Clock.tick(99);

    expect(callback).not.toHaveBeenCalled();
  });

  it("should clear previous requests", function () {
    throttler.queue("LOL", callback);
    jasmine.Clock.tick(99);
    throttler.queue("ROFL", callback);
    jasmine.Clock.tick(150);

    expect(callback).toHaveBeenCalledWith("ROFL");
  });

  it("should discard equal requests", function () {
    throttler.queue("LOL", callback);
    jasmine.Clock.tick(150);

    throttler.queue("LOL", callback);
    jasmine.Clock.tick(150);

    expect(callback).toHaveBeenCalledWith("LOL");
    expect(callback.callCount).toEqual(1);
  });

});