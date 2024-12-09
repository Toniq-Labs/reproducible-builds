import Blob "mo:base/Blob";
import Text "mo:base/Text";

module {

  public type HeaderField = (Text,Text);

  public type Request = {
    method  : Text;
    url     : Text;
    headers : [HeaderField];
    body    : Blob;
  };

  public type Response = {
    status_code        : Nat16;
    headers            : [HeaderField];
    body               : Blob;
    streaming_strategy : ?StreamingStrategy;
  };

  public type StreamingCallback = query (StreamingToken) -> async StreamingResponse;

  public type StreamingStrategy = {
    #Callback : {
      callback: StreamingCallback;
      token: StreamingToken;
    };
  };
  
  public type StreamingResponse = {
    body  : Blob;
    token : ?StreamingToken;
  };

  public type StreamingToken = {
    start  : (Nat,Nat);
    stop   : (Nat,Nat);
    key    : Text;
    nested : [(StreamingCallback,StreamingToken)];
  };

  public type DownloadResponse = {
    body  : Blob;
    token : ?DownloadToken;
  };

  public type DownloadToken = {
    start  : (Nat,Nat);
    stop   : (Nat,Nat);
  };

  public func NOT_FOUND() : Response {
    return {
      status_code = 404;
      headers = [];
      body = Blob.fromArray([]);
      streaming_strategy = null;
    };
  };

  public func BAD_REQUEST() : Response {
    return {
      status_code = 400;
      headers = [];
      body = Blob.fromArray([]);
      streaming_strategy = null;
    };
  };

  public func UNAUTHORIZED() : Response {
    return {
      status_code = 401;
      headers = [];
      body = Blob.fromArray([]);
      streaming_strategy = null;
    };
  };

  public func LEGAL() : Response {
    return {
      status_code = 451;
      headers = [];
      body = Blob.fromArray([]);
      streaming_strategy = null;
    };
  };

  public func generic( ctype : Text, payload : Blob, strategy : ?StreamingStrategy ) : Response {
    return {
      status_code = 200;
      headers = [("content-type", ctype)];
      body = payload;
      streaming_strategy = strategy;
    };
  };

};