// Type declarations for Express
// This file provides type definitions until @types/express is properly installed

declare module 'express' {
  export interface Request {
    params: Record<string, string>;
    query: Record<string, string | string[] | undefined>;
    body: any;
    ip: string;
    socket: {
      remoteAddress?: string;
    };
    headers: Record<string, string | string[] | undefined>;
    cookies: Record<string, string>;
    get(name: string): string | undefined;
    user?: any;
  }

  export interface Response {
    status(code: number): this;
    json(body: any): this;
    send(body?: any): this;
    cookie(name: string, value: string, options?: any): this;
    clearCookie(name: string, options?: any): this;
    setHeader(name: string, value: string | string[]): this;
  }

  export type NextFunction = (err?: any) => void;

  export interface Application {
    use(...handlers: Array<((req: Request, res: Response, next?: NextFunction) => void | Promise<void>) | ((err: any, req: Request, res: Response, next: NextFunction) => void) | Router>): void;
    listen(port: number, callback?: () => void): void;
    json(): any;
    post(path: string, ...handlers: Array<(req: Request, res: Response, next?: NextFunction) => void | Promise<void>>): void;
    get(path: string, ...handlers: Array<(req: Request, res: Response, next?: NextFunction) => void | Promise<void>>): void;
  }

  export interface Router {
    get(path: string, ...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
    post(path: string, ...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
    put(path: string, ...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
    delete(path: string, ...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
    patch(path: string, ...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
    use(...handlers: Array<((req: Request | any, res: Response, next?: NextFunction) => void | Promise<void>) | Router>): void;
  }

  export interface Application {
    use(...handlers: Array<(req: Request, res: Response, next?: NextFunction) => void | Promise<void>>): void;
    listen(port: number, callback?: () => void): void;
  }

  function express(): Application;
  export default express;
  export function Router(): Router;
  
  // Export Application type for use in tests
  export type { Application };
}

