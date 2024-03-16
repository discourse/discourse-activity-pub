import Controller from "@ember/controller";
import { newActor } from "../models/activity-pub-actor";

export default class adminActivityPub extends Controller {
  newActor = newActor;
}
